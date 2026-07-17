import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../file_saver.dart';
import '../media/ffmpeg_service.dart';
import '../media/ffmpeg_setup.dart';
import '../media/preview_file.dart';

/// A stretch of the original timeline the user has cut out.
class _CutRegion {
  const _CutRegion(this.start, this.end);
  final double start;
  final double end;
}

/// An exportable output format with its ffmpeg codec recipe.
class _ExportFormat {
  const _ExportFormat(this.label, this.extension, this.mimeType, this.args);
  final String label;
  final String extension;
  final String mimeType;
  final List<String> args;
}

const _exportFormats = [
  _ExportFormat('MP3', 'mp3', 'audio/mpeg', ['-c:a', 'libmp3lame', '-q:a', '2']),
  _ExportFormat('WAV', 'wav', 'audio/wav', ['-c:a', 'pcm_s16le']),
  _ExportFormat('FLAC', 'flac', 'audio/flac', ['-c:a', 'flac']),
  _ExportFormat('M4A', 'm4a', 'audio/mp4', ['-c:a', 'aac', '-b:a', '192k']),
];

/// The five graphic-equalizer bands (center frequencies in Hz).
const _eqBands = [60.0, 230.0, 910.0, 3600.0, 14000.0];
const _eqBandLabels = ['60', '230', '910', '3.6k', '14k'];

const _eqPresets = <String, List<double>>{
  'Flat': [0, 0, 0, 0, 0],
  'Bass boost': [6, 4, 1, 0, 0],
  'Vocal': [-2, 0, 3, 3, -1],
  'Treble': [0, 0, 1, 3, 5],
};

enum _PlaybackState { idle, rendering, playing, paused }

/// Audio editor: cut pieces out of the timeline on a waveform, shape the
/// sound with a 5-band equalizer plus gain/speed/fades, preview the result
/// through the speakers, then export to MP3/WAV/FLAC/M4A. All processing is
/// done by ffmpeg, like the other media tools.
class AudioEditorView extends StatefulWidget {
  const AudioEditorView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AudioEditorView> createState() => _AudioEditorViewState();
}

class _AudioEditorViewState extends State<AudioEditorView> {
  bool? _ffmpegReady;

  String? _path;
  String? _name;
  int _size = 0;
  bool _loadingFile = false;

  double _duration = 0;
  Float32List? _peaks;

  // Selection on the original timeline, used for cutting.
  double _selStart = 0;
  double _selEnd = 0;
  final List<_CutRegion> _cuts = [];

  // Equalizer + effects.
  List<double> _eqGains = List.filled(_eqBands.length, 0.0);
  double _gainDb = 0;
  double _tempo = 1.0;
  double _fadeIn = 0;
  double _fadeOut = 0;

  // Preview playback.
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _playerSubs = [];
  _PlaybackState _playback = _PlaybackState.idle;
  String? _previewPath;
  bool _previewDirty = true;
  Duration _position = Duration.zero;
  Duration _previewDuration = Duration.zero;

  int _exportFormat = 0;
  bool _saving = false;
  String? _error;
  SaveResult? _result;

  @override
  void initState() {
    super.initState();
    _checkFfmpeg();
    _playerSubs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _playerSubs.add(_player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _previewDuration = d);
    }));
    _playerSubs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playback = _PlaybackState.idle;
          _position = Duration.zero;
        });
      }
    }));
  }

  @override
  void dispose() {
    for (final sub in _playerSubs) {
      sub.cancel();
    }
    _player.dispose();
    final preview = _previewPath;
    if (preview != null) deletePreviewFile(preview);
    super.dispose();
  }

  Future<void> _checkFfmpeg() async {
    final ready = await Ffmpeg.available();
    if (!mounted) return;
    setState(() => _ffmpegReady = ready);
  }

  // ── File loading ──────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'mp3', 'ogg', 'flac', 'm4a', 'wav', 'aac', 'opus', 'wma', 'aiff',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) {
      setState(() =>
          _error = 'Could not read the file path — editing needs the desktop app.');
      return;
    }

    await _stopPlayback();
    setState(() {
      _path = path;
      _name = file.name;
      _size = file.size;
      _loadingFile = true;
      _duration = 0;
      _peaks = null;
      _cuts.clear();
      _eqGains = List.filled(_eqBands.length, 0.0);
      _gainDb = 0;
      _tempo = 1.0;
      _fadeIn = 0;
      _fadeOut = 0;
      _previewDirty = true;
      _error = null;
      _result = null;
    });

    try {
      final info = await Ffmpeg.probeVideo(path);
      if (info.durationSec <= 0 || !info.hasAudio) {
        throw const FfmpegException('Could not read this audio file.');
      }
      // Decode to low-rate mono PCM to draw the waveform.
      final pcm = await Ffmpeg.transcodePath(
        inputPath: path,
        args: const ['-vn', '-ac', '1', '-ar', '2000', '-f', 's16le'],
        outputExtension: 'pcm',
      );
      if (!mounted || _path != path) return;
      setState(() {
        _loadingFile = false;
        _duration = info.durationSec;
        _selStart = 0;
        _selEnd = info.durationSec;
        _peaks = _peaksFromPcm(pcm, 700);
      });
    } on FfmpegException catch (e) {
      if (!mounted || _path != path) return;
      setState(() {
        _loadingFile = false;
        _path = null;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted || _path != path) return;
      setState(() {
        _loadingFile = false;
        _path = null;
        _error = 'Could not load this file: $e';
      });
    }
  }

  static Float32List _peaksFromPcm(Uint8List bytes, int buckets) {
    final samples = bytes.buffer
        .asInt16List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);
    final peaks = Float32List(buckets);
    if (samples.isEmpty) return peaks;
    final perBucket = math.max(1, samples.length ~/ buckets);
    var overallMax = 1;
    for (var b = 0; b < buckets; b++) {
      final start = b * samples.length ~/ buckets;
      final end = math.min(samples.length, start + perBucket);
      var maxAbs = 0;
      for (var i = start; i < end; i++) {
        final v = samples[i].abs();
        if (v > maxAbs) maxAbs = v;
      }
      peaks[b] = maxAbs.toDouble();
      if (maxAbs > overallMax) overallMax = maxAbs;
    }
    for (var b = 0; b < buckets; b++) {
      peaks[b] /= overallMax;
    }
    return peaks;
  }

  // ── Edit model ────────────────────────────────────────────────────────

  /// The stretches of the original timeline that survive the cuts, in order.
  List<(double, double)> _keptIntervals() {
    final cuts = [..._cuts]..sort((a, b) => a.start.compareTo(b.start));
    final kept = <(double, double)>[];
    var cursor = 0.0;
    for (final c in cuts) {
      if (c.start > cursor + 0.01) kept.add((cursor, c.start));
      if (c.end > cursor) cursor = c.end;
    }
    if (cursor < _duration - 0.01) kept.add((cursor, _duration));
    return kept;
  }

  double get _keptDuration =>
      _keptIntervals().fold(0.0, (sum, k) => sum + (k.$2 - k.$1));

  /// Duration of the final output, after cuts and the speed change.
  double get _outputDuration => _keptDuration / _tempo;

  bool get _hasEqOrEffects =>
      _eqGains.any((g) => g.abs() >= 0.05) ||
      _gainDb.abs() >= 0.05 ||
      (_tempo - 1.0).abs() >= 0.005 ||
      _fadeIn >= 0.05 ||
      _fadeOut >= 0.05;

  bool get _isEdited => _cuts.isNotEmpty || _hasEqOrEffects;

  /// Builds the `-filter_complex` args implementing cuts (atrim + concat)
  /// followed by the EQ/effects chain. Empty when nothing is edited.
  List<String> _buildFilterArgs() {
    final kept = _keptIntervals();
    if (kept.isEmpty) {
      throw const FfmpegException(
          'Everything has been cut — remove a cut first.');
    }

    final effects = <String>[];
    for (var i = 0; i < _eqBands.length; i++) {
      if (_eqGains[i].abs() >= 0.05) {
        effects.add('equalizer=f=${_eqBands[i].round()}:t=q:w=1.0'
            ':g=${_eqGains[i].toStringAsFixed(1)}');
      }
    }
    if (_gainDb.abs() >= 0.05) {
      effects.add('volume=${_gainDb.toStringAsFixed(1)}dB');
    }
    if ((_tempo - 1.0).abs() >= 0.005) {
      effects.add('atempo=${_tempo.toStringAsFixed(2)}');
    }
    if (_fadeIn >= 0.05) {
      effects.add('afade=t=in:st=0:d=${_fadeIn.toStringAsFixed(1)}');
    }
    if (_fadeOut >= 0.05) {
      final start = math.max(0.0, _outputDuration - _fadeOut);
      effects.add('afade=t=out:st=${start.toStringAsFixed(2)}'
          ':d=${_fadeOut.toStringAsFixed(1)}');
    }

    if (_cuts.isEmpty && effects.isEmpty) return const [];

    final parts = <String>[];
    String src;
    if (_cuts.isNotEmpty) {
      final labels = <String>[];
      for (var i = 0; i < kept.length; i++) {
        parts.add('[0:a]atrim=start=${kept[i].$1.toStringAsFixed(3)}'
            ':end=${kept[i].$2.toStringAsFixed(3)},'
            'asetpts=PTS-STARTPTS[s$i]');
        labels.add('[s$i]');
      }
      if (kept.length > 1) {
        parts.add('${labels.join()}concat=n=${kept.length}:v=0:a=1[cat]');
        src = '[cat]';
      } else {
        src = '[s0]';
      }
    } else {
      src = '[0:a]';
    }
    parts.add(effects.isEmpty
        ? '${src}anull[out]'
        : '$src${effects.join(',')}[out]');

    return ['-filter_complex', parts.join(';'), '-map', '[out]'];
  }

  /// Applies an edit mutation, invalidating the rendered preview.
  void _edit(VoidCallback change) {
    setState(() {
      change();
      _previewDirty = true;
      _result = null;
    });
  }

  void _cutSelection() {
    if (_selEnd - _selStart < 0.05) return;
    _edit(() => _cuts.add(_CutRegion(_selStart, _selEnd)));
  }

  void _keepOnlySelection() {
    if (_selEnd - _selStart < 0.05) return;
    _edit(() {
      _cuts.clear();
      if (_selStart > 0.01) _cuts.add(_CutRegion(0, _selStart));
      if (_selEnd < _duration - 0.01) {
        _cuts.add(_CutRegion(_selEnd, _duration));
      }
    });
  }

  // ── Preview playback ──────────────────────────────────────────────────

  Future<void> _stopPlayback() async {
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _playback = _PlaybackState.idle;
      _position = Duration.zero;
    });
  }

  Future<void> _togglePreview() async {
    switch (_playback) {
      case _PlaybackState.playing:
        await _player.pause();
        if (mounted) setState(() => _playback = _PlaybackState.paused);
      case _PlaybackState.paused when !_previewDirty:
        await _player.resume();
        if (mounted) setState(() => _playback = _PlaybackState.playing);
      case _PlaybackState.rendering:
        break;
      default:
        await _renderAndPlay();
    }
  }

  Future<void> _renderAndPlay() async {
    final path = _path;
    if (path == null) return;

    setState(() {
      _playback = _PlaybackState.rendering;
      _error = null;
    });

    try {
      String playPath;
      if (_previewDirty || _previewPath == null) {
        final args = _buildFilterArgs();
        if (args.isEmpty) {
          // Nothing edited: play the original file as-is.
          playPath = path;
        } else {
          final bytes = await Ffmpeg.transcodePath(
            inputPath: path,
            args: [...args, '-c:a', 'pcm_s16le'],
            outputExtension: 'wav',
          );
          final old = _previewPath;
          if (old != null) await deletePreviewFile(old);
          _previewPath = null;
          final written = await writePreviewFile(bytes, 'wav');
          if (written == null) {
            throw const FfmpegException(
                'Preview playback is only available in the desktop app.');
          }
          _previewPath = written;
          playPath = written;
        }
        _previewDirty = false;
      } else {
        playPath = _previewPath!;
      }
      await _player.stop();
      await _player.play(DeviceFileSource(playPath));
      if (!mounted) return;
      setState(() {
        _playback = _PlaybackState.playing;
        _position = Duration.zero;
      });
    } on FfmpegException catch (e) {
      if (!mounted) return;
      setState(() {
        _playback = _PlaybackState.idle;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _playback = _PlaybackState.idle;
        _error = 'Could not play the preview: $e';
      });
    }
  }

  // ── Export ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final path = _path;
    final name = _name;
    if (path == null || name == null) return;

    await _stopPlayback();
    setState(() {
      _saving = true;
      _error = null;
      _result = null;
    });

    final format = _exportFormats[_exportFormat];
    try {
      final bytes = await Ffmpeg.transcodePath(
        inputPath: path,
        args: [..._buildFilterArgs(), ...format.args],
        outputExtension: format.extension,
      );
      final save = await saveConvertedFile(
        bytes: bytes,
        suggestedName: '${_stripExtension(name)}_edited.${format.extension}',
        mimeType: format.mimeType,
        extensions: [format.extension],
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _result = save;
      });
    } on FfmpegException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save: $e';
      });
    }
  }

  Future<void> _reset() async {
    await _stopPlayback();
    setState(() {
      _path = null;
      _name = null;
      _size = 0;
      _duration = 0;
      _peaks = null;
      _cuts.clear();
      _error = null;
      _result = null;
      _previewDirty = true;
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final ready = _ffmpegReady ?? false;
    final loaded = _path != null && _duration > 0 && !_loadingFile;

    return ToolScaffold(
      icon: Icons.equalizer_rounded,
      title: 'Audio editor',
      subtitle: 'Cut, equalize, and preview audio before exporting',
      onBack: widget.onBack,
      children: [
        if (_ffmpegReady == false) ...[
          FfmpegSetup(onReady: () => setState(() => _ffmpegReady = true)),
          const SizedBox(height: 16),
        ],
        if (_path == null)
          ConverterDropZone(
            onTap: _pickFile,
            icon: Icons.library_music_outlined,
            title: 'Click to choose an audio file',
            subtitle: 'MP3 · OGG · FLAC · M4A · WAV · AAC',
          )
        else ...[
          ConverterFileCard(
            name: _name!,
            icon: Icons.music_note_rounded,
            meta: _duration > 0
                ? '${formatBytes(_size)} · ${_fmtTime(_duration)}'
                : formatBytes(_size),
            onChange: _pickFile,
          ),
          if (_loadingFile) ...[
            const SizedBox(height: 16),
            ConverterCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(luma.accent),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Reading audio & building waveform…',
                    style: TextStyle(color: luma.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (loaded) ...[
          const SizedBox(height: 16),
          _buildTrimSection(luma),
          const SizedBox(height: 16),
          _buildEqualizerSection(luma),
          const SizedBox(height: 16),
          _buildEffectsSection(luma),
          const SizedBox(height: 16),
          _buildPreviewSection(luma),
          const SizedBox(height: 16),
          _buildExportSection(luma, ready),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.error_outline_rounded,
            color: luma.danger,
            message: _error!,
          ),
        ],
        if (_result != null && _result!.saved) ...[
          const SizedBox(height: 16),
          ConverterBanner(
            icon: Icons.check_circle_outline_rounded,
            color: luma.success,
            message: _result!.summary,
            trailing: ConverterTextButton(label: 'Edit another', onTap: _reset),
          ),
        ],
      ],
    );
  }

  Widget _buildTrimSection(LumaPalette luma) {
    return _EditorSection(
      title: 'Cut & trim',
      subtitle: 'Drag on the waveform to select a range, then cut it out or '
          'keep only the selection.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 110,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => _onWaveDrag(d.localPosition, start: true),
              onHorizontalDragUpdate: (d) => _onWaveDrag(d.localPosition),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _waveWidth = constraints.maxWidth;
                  return CustomPaint(
                    size: Size(constraints.maxWidth, 110),
                    painter: _WaveformPainter(
                      peaks: _peaks ?? Float32List(0),
                      duration: _duration,
                      selStart: _selStart,
                      selEnd: _selEnd,
                      cuts: _cuts,
                      barColor: luma.textMuted,
                      selectedBarColor: luma.accent,
                      selectionFill: luma.accent.withValues(alpha: 0.10),
                      cutFill: luma.danger.withValues(alpha: 0.16),
                      edgeColor: luma.accent,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: luma.accent,
              inactiveTrackColor: luma.surfaceHover,
              thumbColor: luma.accent,
              overlayColor: luma.accent.withValues(alpha: 0.12),
              trackHeight: 4,
              rangeThumbShape:
                  const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: RangeSlider(
              values: RangeValues(
                _selStart.clamp(0, _duration),
                _selEnd.clamp(0, _duration),
              ),
              min: 0,
              max: _duration,
              onChanged: (v) => setState(() {
                _selStart = v.start;
                _selEnd = v.end;
              }),
            ),
          ),
          Row(
            children: [
              Text(
                'Selection  ${_fmtTime(_selStart)} – ${_fmtTime(_selEnd)}',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                'Output ${_fmtTime(_outputDuration)} of ${_fmtTime(_duration)}',
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ToolChip(
                icon: Icons.content_cut_rounded,
                label: 'Cut selection out',
                onTap: _cutSelection,
              ),
              _ToolChip(
                icon: Icons.crop_rounded,
                label: 'Keep only selection',
                onTap: _keepOnlySelection,
              ),
              if (_cuts.isNotEmpty)
                _ToolChip(
                  icon: Icons.undo_rounded,
                  label: 'Clear all cuts',
                  onTap: () => _edit(_cuts.clear),
                ),
            ],
          ),
          if (_cuts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _cuts.length; i++)
                  _CutChip(
                    label:
                        '${_fmtTime(_cuts[i].start)} – ${_fmtTime(_cuts[i].end)}',
                    onRemove: () => _edit(() => _cuts.removeAt(i)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  double _waveWidth = 1;
  double _dragAnchor = 0;

  void _onWaveDrag(Offset local, {bool start = false}) {
    if (_duration <= 0 || _waveWidth <= 0) return;
    final t = (local.dx / _waveWidth * _duration).clamp(0.0, _duration);
    setState(() {
      if (start) {
        _dragAnchor = t;
        _selStart = t;
        _selEnd = t;
      } else {
        _selStart = math.min(_dragAnchor, t);
        _selEnd = math.max(_dragAnchor, t);
      }
    });
  }

  Widget _buildEqualizerSection(LumaPalette luma) {
    String? activePreset;
    for (final preset in _eqPresets.entries) {
      if (_listEquals(preset.value, _eqGains)) {
        activePreset = preset.key;
        break;
      }
    }
    return _EditorSection(
      title: 'Equalizer',
      subtitle: 'Boost or cut each band by up to 12 dB.',
      trailing: activePreset == 'Flat'
          ? null
          : ConverterTextButton(
              label: 'Reset',
              onTap: () =>
                  _edit(() => _eqGains = List.filled(_eqBands.length, 0.0)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < _eqBands.length; i++)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_eqGains[i] >= 0 ? '+' : ''}'
                        '${_eqGains[i].toStringAsFixed(0)} dB',
                        style: TextStyle(
                          color: _eqGains[i].abs() >= 0.5
                              ? luma.accent
                              : luma.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      SizedBox(
                        height: 130,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: luma.accent,
                              inactiveTrackColor: luma.surfaceHover,
                              thumbColor: luma.accent,
                              overlayColor:
                                  luma.accent.withValues(alpha: 0.12),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _eqGains[i].clamp(-12, 12),
                              min: -12,
                              max: 12,
                              onChanged: (v) => _edit(() => _eqGains[i] = v),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '${_eqBandLabels[i]} Hz',
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _eqPresets.entries)
                _ToolChip(
                  icon: Icons.tune_rounded,
                  label: preset.key,
                  active: activePreset == preset.key,
                  onTap: () => _edit(() => _eqGains = [...preset.value]),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEffectsSection(LumaPalette luma) {
    return _EditorSection(
      title: 'Effects',
      child: Column(
        children: [
          _EditorSlider(
            label: 'Volume',
            value: _gainDb,
            min: -12,
            max: 12,
            display: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)} dB',
            onChanged: (v) => _edit(() => _gainDb = v),
          ),
          const SizedBox(height: 8),
          _EditorSlider(
            label: 'Speed',
            value: _tempo,
            min: 0.5,
            max: 2.0,
            display: (v) => '${v.toStringAsFixed(2)}×',
            onChanged: (v) => _edit(() => _tempo = v),
          ),
          const SizedBox(height: 8),
          _EditorSlider(
            label: 'Fade in',
            value: _fadeIn,
            min: 0,
            max: 10,
            display: (v) => '${v.toStringAsFixed(1)} s',
            onChanged: (v) => _edit(() => _fadeIn = v),
          ),
          const SizedBox(height: 8),
          _EditorSlider(
            label: 'Fade out',
            value: _fadeOut,
            min: 0,
            max: 10,
            display: (v) => '${v.toStringAsFixed(1)} s',
            onChanged: (v) => _edit(() => _fadeOut = v),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(LumaPalette luma) {
    final playing = _playback == _PlaybackState.playing;
    final rendering = _playback == _PlaybackState.rendering;
    final total = _previewDuration.inMilliseconds;
    final progress =
        total <= 0 ? 0.0 : (_position.inMilliseconds / total).clamp(0.0, 1.0);
    return _EditorSection(
      title: 'Preview',
      subtitle: _previewDirty && _isEdited
          ? 'Renders your edits, then plays the result.'
          : 'Hear exactly what will be exported.',
      child: Row(
        children: [
          _RoundIconButton(
            icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            busy: rendering,
            onTap: _togglePreview,
          ),
          const SizedBox(width: 10),
          _RoundIconButton(
            icon: Icons.stop_rounded,
            filled: false,
            onTap: _playback == _PlaybackState.playing ||
                    _playback == _PlaybackState.paused
                ? _stopPlayback
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: luma.surfaceHover,
                valueColor: AlwaysStoppedAnimation(luma.accent),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${_fmtDuration(_position)} / ${_fmtDuration(_previewDuration)}',
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection(LumaPalette luma, bool ready) {
    return _EditorSection(
      title: 'Export',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _exportFormats.length; i++)
                _ToolChip(
                  icon: Icons.audio_file_outlined,
                  label: _exportFormats[i].label,
                  active: _exportFormat == i,
                  onTap: () => setState(() => _exportFormat = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ConverterPrimaryButton(
            label: 'Generate & save',
            icon: Icons.download_rounded,
            loading: _saving,
            onTap: ready && _isEdited ? _save : null,
          ),
          if (!_isEdited) ...[
            const SizedBox(height: 10),
            Text(
              'Make an edit above to enable exporting.',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

bool _listEquals(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > 0.01) return false;
  }
  return true;
}

String _fmtTime(double seconds) {
  final s = seconds.isFinite ? seconds : 0.0;
  final m = s ~/ 60;
  final sec = (s % 60).floor();
  return '$m:${sec.toString().padLeft(2, '0')}';
}

String _fmtDuration(Duration d) =>
    _fmtTime(d.inMilliseconds / 1000.0);

String _stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/// Card with a bold section title, optional subtitle, and its controls.
class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConverterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(color: luma.textMuted, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Labeled slider row with a live value readout, themed to luma's accent.
class _EditorSlider extends StatelessWidget {
  const _EditorSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.display,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double value) display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: luma.accent,
              inactiveTrackColor: luma.surfaceHover,
              thumbColor: luma.accent,
              overlayColor: luma.accent.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            display(value),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

/// Icon + label pill button. Highlights with the accent color while active.
class _ToolChip extends StatefulWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ToolChip> createState() => _ToolChipState();
}

class _ToolChipState extends State<_ToolChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final active = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? luma.accent : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: active ? luma.accent : luma.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: active ? luma.accent : luma.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small removable chip showing one cut region's time range.
class _CutChip extends StatelessWidget {
  const _CutChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: luma.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.content_cut_rounded, size: 14, color: luma.danger),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child:
                    Icon(Icons.close_rounded, size: 15, color: luma.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular play/pause/stop control for the preview player.
class _RoundIconButton extends StatefulWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.busy = false,
    this.filled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;
  final bool filled;

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final enabled = widget.onTap != null && !widget.busy;
    final Color bg;
    final Color fg;
    if (widget.filled) {
      bg = !enabled && !widget.busy
          ? luma.accent.withValues(alpha: 0.4)
          : (_hovering ? luma.accentHover : luma.accent);
      fg = luma.onAccent;
    } else {
      bg = _hovering && enabled ? luma.surfaceHover : Colors.transparent;
      fg = enabled ? luma.textSecondary : luma.textMuted;
    }
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: widget.filled
                ? null
                : Border.all(color: luma.border),
          ),
          child: widget.busy
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(
                        widget.filled ? luma.onAccent : luma.accent),
                  ),
                )
              : Icon(widget.icon, color: fg, size: 24),
        ),
      ),
    );
  }
}

/// Draws the waveform bars, the current selection, and cut-region overlays.
class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.peaks,
    required this.duration,
    required this.selStart,
    required this.selEnd,
    required this.cuts,
    required this.barColor,
    required this.selectedBarColor,
    required this.selectionFill,
    required this.cutFill,
    required this.edgeColor,
  });

  final Float32List peaks;
  final double duration;
  final double selStart;
  final double selEnd;
  final List<_CutRegion> cuts;
  final Color barColor;
  final Color selectedBarColor;
  final Color selectionFill;
  final Color cutFill;
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (duration <= 0) return;
    final midY = size.height / 2;

    double xOf(double t) => (t / duration).clamp(0.0, 1.0) * size.width;

    // Selection fill behind the bars.
    if (selEnd > selStart) {
      canvas.drawRect(
        Rect.fromLTRB(xOf(selStart), 0, xOf(selEnd), size.height),
        Paint()..color = selectionFill,
      );
    }

    // Waveform bars.
    if (peaks.isNotEmpty) {
      final barPaint = Paint()..strokeWidth = 1.6;
      final n = peaks.length;
      final step = size.width / n;
      for (var i = 0; i < n; i++) {
        final x = i * step + step / 2;
        final t = (i + 0.5) / n * duration;
        final inCut = cuts.any((c) => t >= c.start && t <= c.end);
        final inSel = t >= selStart && t <= selEnd;
        barPaint.color = inCut
            ? barColor.withValues(alpha: 0.35)
            : (inSel ? selectedBarColor : barColor);
        final h = math.max(1.5, peaks[i] * (size.height - 10) / 2);
        canvas.drawLine(
            Offset(x, midY - h), Offset(x, midY + h), barPaint);
      }
    }

    // Cut-region tint on top.
    final cutPaint = Paint()..color = cutFill;
    for (final c in cuts) {
      canvas.drawRect(
        Rect.fromLTRB(xOf(c.start), 0, xOf(c.end), size.height),
        cutPaint,
      );
    }

    // Selection edge lines.
    if (selEnd > selStart) {
      final edgePaint = Paint()
        ..color = edgeColor
        ..strokeWidth = 2;
      canvas.drawLine(Offset(xOf(selStart), 0),
          Offset(xOf(selStart), size.height), edgePaint);
      canvas.drawLine(Offset(xOf(selEnd), 0),
          Offset(xOf(selEnd), size.height), edgePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => true;
}
