import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../converter_widgets.dart';
import '../file_saver.dart';
import '../media/ffmpeg_service.dart';
import '../media/ffmpeg_setup.dart';
import '../video_downscaler_service.dart';

/// The individual video optimizations, in display order.
enum VdOption {
  resize,
  quality,
  fps,
  h265,
  reduceAudio,
  removeAudio,
  stripMetadata,
  webm,
}

const _sampleSeconds = 4.0;

/// Video downscaler: stack ffmpeg-backed optimizations with a sample-based
/// size estimate.
class VideoDownscalerView extends StatefulWidget {
  const VideoDownscalerView({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<VideoDownscalerView> createState() => _VideoDownscalerViewState();
}

class _VideoDownscalerViewState extends State<VideoDownscalerView> {
  bool _ffmpegReady = false;

  String? _path;
  String? _name;
  int _originalSize = 0;

  VideoInfo? _info;
  bool _probing = false;

  VideoParams _params = const VideoParams();

  int? _estimatedSize;
  bool _estimating = false;
  Timer? _debounce;
  int _gen = 0;

  bool _applying = false;
  String? _error;
  SaveResult? _result;

  @override
  void initState() {
    super.initState();
    _checkFfmpeg();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkFfmpeg() async {
    if (kIsWeb) return;
    final ready = await Ffmpeg.available();
    if (!mounted) return;
    setState(() => _ffmpegReady = ready);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'mkv', 'webm', 'm4v', 'avi'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) {
      setState(() => _error = L.of(context).vidDownNoPath);
      return;
    }

    setState(() {
      _path = path;
      _name = file.name;
      _originalSize = file.size;
      _params = const VideoParams();
      _info = null;
      _probing = true;
      _estimatedSize = null;
      _result = null;
      _error = null;
      _gen++;
    });

    final gen = _gen;
    final info = await Ffmpeg.probeVideo(path);
    if (!mounted || gen != _gen) return;
    setState(() {
      _probing = false;
      _info = info;
      _error = info.ok ? null : L.of(context).vidDownProbeFailed;
    });
  }

  bool _enabledFor(VdOption o) {
    final info = _info;
    if (info == null) return false;
    switch (o) {
      case VdOption.removeAudio:
      case VdOption.reduceAudio:
        return info.hasAudio;
      default:
        return true;
    }
  }

  bool _isChecked(VdOption o) => switch (o) {
        VdOption.resize => _params.resize,
        VdOption.quality => _params.quality,
        VdOption.fps => _params.fps,
        VdOption.h265 => _params.h265,
        VdOption.reduceAudio => _params.reduceAudio,
        VdOption.removeAudio => _params.removeAudio,
        VdOption.stripMetadata => _params.stripMetadata,
        VdOption.webm => _params.webm,
      };

  void _toggle(VdOption o, bool value) {
    switch (o) {
      case VdOption.resize:
        _update(_params.copyWith(resize: value));
      case VdOption.quality:
        _update(_params.copyWith(quality: value));
      case VdOption.fps:
        _update(_params.copyWith(fps: value));
      case VdOption.h265:
        // H.265 and WebP/VP9 are mutually exclusive codec choices.
        _update(_params.copyWith(h265: value, webm: value ? false : null));
      case VdOption.webm:
        _update(_params.copyWith(webm: value, h265: value ? false : null));
      case VdOption.reduceAudio:
        _update(_params.copyWith(
            reduceAudio: value, removeAudio: value ? false : null));
      case VdOption.removeAudio:
        _update(_params.copyWith(
            removeAudio: value, reduceAudio: value ? false : null));
      case VdOption.stripMetadata:
        _update(_params.copyWith(stripMetadata: value));
    }
  }

  void _update(VideoParams next) {
    setState(() => _params = next);
    _scheduleEstimate();
  }

  void _scheduleEstimate() {
    _debounce?.cancel();
    if (!_params.anySelected) {
      setState(() {
        _estimatedSize = null;
        _estimating = false;
      });
      return;
    }
    setState(() => _estimating = true);
    _debounce = Timer(const Duration(milliseconds: 600), _computeEstimate);
  }

  Future<void> _computeEstimate() async {
    final path = _path;
    final info = _info;
    if (path == null || info == null || !info.ok) return;
    final gen = _gen;
    try {
      final args = VideoDownscalerService.buildArgs(_params, info);
      final duration = info.durationSec;
      final sample = math.min(_sampleSeconds, duration);
      final start = duration > sample * 2
          ? math.min(duration * 0.1, duration - sample)
          : 0.0;

      final sampleBytes = await Ffmpeg.sampleSize(
        inputPath: path,
        args: args,
        outputExtension: _params.outputExtension,
        startSeconds: start,
        sampleSeconds: sample,
      );
      if (!mounted || gen != _gen) return;
      final estimated = (sample <= 0 || sample >= duration)
          ? sampleBytes
          : (sampleBytes * duration / sample).round();
      setState(() {
        _estimatedSize = estimated;
        _estimating = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _estimating = false;
        _error = L.of(context).vidDownEstimateFailed('$e');
      });
    }
  }

  Future<void> _apply() async {
    final path = _path;
    final name = _name;
    final info = _info;
    if (path == null || name == null || info == null) return;
    setState(() {
      _applying = true;
      _error = null;
      _result = null;
    });
    try {
      final args = VideoDownscalerService.buildArgs(_params, info);
      final out = await Ffmpeg.transcodePath(
        inputPath: path,
        args: args,
        outputExtension: _params.outputExtension,
      );
      final save = await saveConvertedFile(
        bytes: out,
        suggestedName:
            '${_stripExtension(name)}-smaller.${_params.outputExtension}',
        mimeType: _params.mimeType,
        extensions: [_params.outputExtension],
      );
      if (!mounted) return;
      setState(() {
        _applying = false;
        _result = save;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _error = L.of(context).commonErrorDetail('$e');
      });
    }
  }

  void _reset() {
    setState(() {
      _path = null;
      _name = null;
      _originalSize = 0;
      _info = null;
      _params = const VideoParams();
      _estimatedSize = null;
      _result = null;
      _error = null;
      _gen++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final info = _info;
    return ToolScaffold(
      icon: Icons.movie_filter_outlined,
      title: t.converterHubVideoDownscalerTitle,
      subtitle: t.vidDownSubtitle,
      onBack: widget.onBack,
      children: [
        if (!kIsWeb && !_ffmpegReady) ...[
          FfmpegSetup(
            onReady: () => setState(() => _ffmpegReady = true),
          ),
          const SizedBox(height: 16),
        ],
        if (_path == null)
          ConverterDropZone(
            onTap: _pickFile,
            icon: Icons.video_settings_rounded,
            title: t.vidDownPickPrompt,
            subtitle: 'MP4 · MOV · MKV · WEBM · AVI',
          )
        else
          ConverterFileCard(
            name: _name!,
            icon: Icons.videocam_rounded,
            meta: info != null && info.ok
                ? '${info.width}×${info.height} · ${_fmtDuration(info.durationSec)} · ${formatBytes(_originalSize)}'
                : formatBytes(_originalSize),
            onChange: _pickFile,
          ),
        if (_probing) ...[
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.4, color: luma.accent),
            ),
          ),
        ],
        if (info != null && info.ok) ...[
          const SizedBox(height: 16),
          _VideoOptionsCard(view: this),
          const SizedBox(height: 16),
          _VideoEstimateCard(
            originalSize: _originalSize,
            estimatedSize: _estimatedSize,
            estimating: _estimating,
            anySelected: _params.anySelected,
            applying: _applying,
            outputLabel: _params.outputExtension.toUpperCase(),
            onApply: _params.anySelected ? _apply : null,
            t: t,
          ),
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
            trailing: ConverterTextButton(
                label: t.vidDownShrinkAnother, onTap: _reset),
          ),
        ],
      ],
    );
  }
}

class _VideoOptionsCard extends StatelessWidget {
  const _VideoOptionsCard({required this.view});
  final _VideoDownscalerViewState view;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return ConverterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.downscalerOptimizations,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.vidDownOptimizationsHint,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final o in VdOption.values) ...[
            Divider(color: luma.border, height: 20),
            _VideoOptionRow(view: view, option: o),
          ],
        ],
      ),
    );
  }
}

class _VideoOptionRow extends StatelessWidget {
  const _VideoOptionRow({required this.view, required this.option});
  final _VideoDownscalerViewState view;
  final VdOption option;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final meta = _metaFor(t, option);
    final enabled = view._enabledFor(option);
    final checked = view._isChecked(option) && enabled;
    final subtitle =
        enabled ? meta.explanation : (meta.disabledNote ?? meta.explanation);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tooltip(
            message: subtitle,
            waitDuration: const Duration(milliseconds: 250),
            child: Row(
              children: [
                _Check(
                  value: checked,
                  onChanged: enabled ? (v) => view._toggle(option, v) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              meta.title,
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.help_outline_rounded,
                              size: 13, color: luma.textMuted),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (checked) _control(context),
        ],
      ),
    );
  }

  Widget _control(BuildContext context) {
    final p = view._params;
    final t = L.of(context);
    switch (option) {
      case VdOption.resize:
        return _ChoiceRow(
          label: t.vidDownMaxHeight,
          options: [
            for (final h in VideoDownscalerService.heightStops) '${h}p',
          ],
          selectedIndex: VideoDownscalerService.heightStops.indexOf(p.maxHeight),
          onSelect: (i) => view._update(
            p.copyWith(maxHeight: VideoDownscalerService.heightStops[i]),
          ),
        );
      case VdOption.quality:
        return _CrfSlider(
          crf: p.crf,
          onChanged: (v) => view._update(p.copyWith(crf: v)),
        );
      case VdOption.fps:
        return _ChoiceRow(
          label: t.vidDownFrameRate,
          options: [
            for (final f in VideoDownscalerService.fpsStops) '$f fps',
          ],
          selectedIndex: VideoDownscalerService.fpsStops.indexOf(p.targetFps),
          onSelect: (i) => view._update(
            p.copyWith(targetFps: VideoDownscalerService.fpsStops[i]),
          ),
        );
      case VdOption.reduceAudio:
        return _ChoiceRow(
          label: t.vidDownAudio,
          options: [
            for (final a in VideoDownscalerService.audioStops) '$a kbps',
          ],
          selectedIndex: VideoDownscalerService.audioStops.indexOf(p.audioKbps),
          onSelect: (i) => view._update(
            p.copyWith(audioKbps: VideoDownscalerService.audioStops[i]),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _VideoEstimateCard extends StatelessWidget {
  const _VideoEstimateCard({
    required this.originalSize,
    required this.estimatedSize,
    required this.estimating,
    required this.anySelected,
    required this.applying,
    required this.outputLabel,
    required this.onApply,
    required this.t,
  });

  final int originalSize;
  final int? estimatedSize;
  final bool estimating;
  final bool anySelected;
  final bool applying;
  final String outputLabel;
  final VoidCallback? onApply;
  final L t;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final saved =
        estimatedSize == null ? null : originalSize - estimatedSize!;
    final pct = (saved == null || originalSize == 0)
        ? null
        : saved / originalSize * 100;

    return ConverterCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _SizeColumn(
                  label: t.downscalerOriginal,
                  value: formatBytes(originalSize),
                  color: luma.textPrimary,
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  color: luma.textSecondary, size: 20),
              Expanded(
                child: _SizeColumn(
                  label: t.downscalerEstimated(outputLabel),
                  value: !anySelected
                      ? '—'
                      : (estimating || estimatedSize == null
                          ? '…'
                          : '≈ ${formatBytes(estimatedSize!)}'),
                  color: luma.accent,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          if (pct != null && !estimating) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (pct > 0 ? luma.success : luma.danger)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    pct > 0
                        ? Icons.trending_down_rounded
                        : Icons.trending_up_rounded,
                    size: 16,
                    color: pct > 0 ? luma.success : luma.danger,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pct > 0
                        ? t.vidDownSmaller(
                            pct.toStringAsFixed(0),
                            formatBytes(saved!),
                          )
                        : t.vidDownLarger((-pct).toStringAsFixed(0)),
                    style: TextStyle(
                      color: pct > 0 ? luma.success : luma.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (anySelected) ...[
            const SizedBox(height: 8),
            Text(
              t.vidDownSampleNote(_sampleSeconds.toStringAsFixed(0)),
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 16),
          ConverterPrimaryButton(
            label: kIsWeb ? t.vidDownShrinkDownload : t.vidDownShrinkSave,
            icon: Icons.compress_rounded,
            loading: applying,
            onTap: onApply,
          ),
          if (!anySelected) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                t.downscalerSelectOne,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SizeColumn extends StatelessWidget {
  const _SizeColumn({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: onChanged == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: value ? luma.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: value ? luma.accent : luma.border,
              width: 1.5,
            ),
          ),
          child: value
              ? Icon(Icons.check_rounded, size: 16, color: luma.onAccent)
              : null,
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });
  final String label;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.only(left: 34, top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(label,
                style: TextStyle(color: luma.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _MiniPill(
                      label: options[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelect(i),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : luma.surfaceHover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? luma.accent : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? luma.accent : luma.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CrfSlider extends StatelessWidget {
  const _CrfSlider({required this.crf, required this.onChanged});
  final int crf;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // 18 = high quality / larger, 32 = small / lower quality.
    final t = L.of(context);
    final word = crf <= 22
        ? t.vidDownCrfHigh
        : (crf <= 27 ? t.convMediaQualityBalanced : t.vidDownCrfSmallest);
    return Padding(
      padding: const EdgeInsets.only(left: 34, top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(t.convMediaQuality,
                style: TextStyle(color: luma.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Slider(
              value: crf.toDouble().clamp(18, 32),
              min: 18,
              max: 32,
              divisions: 14,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              t.vidDownCrfLabel(word, crf),
              textAlign: TextAlign.end,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoMeta {
  const _VideoMeta(this.title, this.explanation, [this.disabledNote]);
  final String title;
  final String explanation;
  final String? disabledNote;
}

_VideoMeta _metaFor(L t, VdOption option) => switch (option) {
      VdOption.resize => _VideoMeta(
          t.vidDownResizeTitle,
          t.vidDownResizeBody,
        ),
      VdOption.quality => _VideoMeta(
          t.vidDownQualityTitle,
          t.vidDownQualityBody,
        ),
      VdOption.fps => _VideoMeta(
          t.vidDownFpsTitle,
          t.vidDownFpsBody,
        ),
      VdOption.h265 => _VideoMeta(
          t.vidDownH265Title,
          t.vidDownH265Body,
        ),
      VdOption.reduceAudio => _VideoMeta(
          t.vidDownAudioBitrateTitle,
          t.vidDownAudioBitrateBody,
          t.vidDownNoAudio,
        ),
      VdOption.removeAudio => _VideoMeta(
          t.vidDownRemoveAudioTitle,
          t.vidDownRemoveAudioBody,
          t.vidDownNoAudio,
        ),
      VdOption.stripMetadata => _VideoMeta(
          t.vidDownStripTitle,
          t.vidDownStripBody,
        ),
      VdOption.webm => _VideoMeta(
          t.vidDownWebmTitle,
          t.vidDownWebmBody,
        ),
    };

String _stripExtension(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

String _fmtDuration(double seconds) {
  final s = seconds.round();
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}
