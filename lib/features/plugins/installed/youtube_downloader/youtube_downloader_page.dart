import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'download_history_store.dart';
import 'yt_dlp_manager.dart';

class YoutubeDownloaderPage extends StatefulWidget {
  const YoutubeDownloaderPage({super.key});

  @override
  State<YoutubeDownloaderPage> createState() => _YoutubeDownloaderPageState();
}

enum _Stage { settingUp, ready }

class _YoutubeDownloaderPageState extends State<YoutubeDownloaderPage> {
  final _manager = YtDlpManager.instance;
  final _historyStore = DownloadHistoryStore();
  final _urlController = TextEditingController();

  _Stage _stage = _Stage.settingUp;
  ToolSetupProgress? _setupProgress;
  String? _setupError;

  bool _fetching = false;
  String? _fetchError;
  YtVideoInfo? _video;

  DownloadMode _mode = DownloadMode.video;
  int? _videoHeight;
  String _audioFormat = 'mp3';
  int _audioBitrate = 192;
  int _videoAudioBitrate = 192;
  String? _outputDir;

  bool _downloading = false;
  DownloadProgress? _progress;
  String? _downloadError;
  YtDownloadHandle? _activeDownload;

  List<DownloadHistoryEntry> _history = [];

  static const _videoQualities = [2160, 1440, 1080, 720, 480, 360, 240, 144];
  static const _audioFormats = ['mp3', 'm4a', 'opus'];
  static const _bitrates = [96, 128, 160, 192, 256, 320];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _pickDefaultOutputDir();
    await _loadHistory();
    await _setupTools();
  }

  Future<void> _pickDefaultOutputDir() async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) _outputDir = dir.path;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _loadHistory() async {
    final entries = await _historyStore.load();
    if (mounted) setState(() => _history = entries);
  }

  Future<void> _setupTools() async {
    if (await _manager.toolsReady) {
      setState(() => _stage = _Stage.ready);
      return;
    }
    setState(() {
      _stage = _Stage.settingUp;
      _setupError = null;
    });
    try {
      await _manager.ensureTools((p) {
        if (mounted) setState(() => _setupProgress = p);
      });
      if (mounted) setState(() => _stage = _Stage.ready);
    } on YtDlpException catch (e) {
      if (mounted) setState(() => _setupError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _setupError = 'Could not set up yt-dlp / ffmpeg.');
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _fetchError = 'Paste a YouTube link first.');
      return;
    }
    setState(() {
      _fetching = true;
      _fetchError = null;
      _video = null;
    });
    try {
      final info = await _manager.fetchInfo(url);
      setState(() {
        _video = info;
        _videoHeight = info.availableHeights.isNotEmpty
            ? info.availableHeights.last
            : null;
      });
    } on YtDlpException catch (e) {
      setState(() => _fetchError = e.message);
    } catch (_) {
      setState(() => _fetchError = 'Could not read that video.');
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _chooseOutputDir() async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a download folder',
    );
    if (path != null) setState(() => _outputDir = path);
  }

  Future<void> _download() async {
    final url = _urlController.text.trim();
    final video = _video;
    final outputDir = _outputDir;
    if (video == null || url.isEmpty) return;
    if (outputDir == null) {
      setState(() => _downloadError = 'Choose a download folder first.');
      return;
    }

    setState(() {
      _downloading = true;
      _downloadError = null;
      _progress = DownloadProgress(rawLine: 'Starting…');
    });

    final handle = _manager.download(
      url: url,
      mode: _mode,
      outputDir: outputDir,
      videoHeight: _mode == DownloadMode.video ? _videoHeight : null,
      audioFormat: _audioFormat,
      audioBitrateKbps: _mode == DownloadMode.audio
          ? _audioBitrate
          : _videoAudioBitrate,
    );
    _activeDownload = handle;

    String? finalPath;
    try {
      await for (final p in handle.progress) {
        if (!mounted) return;
        setState(() => _progress = p);
        if (p.done) finalPath = p.rawLine;
      }
      final detail = _mode == DownloadMode.video
          ? '${_videoHeight ?? "best"}p · $_videoAudioBitrate kbps audio'
          : '${_audioFormat.toUpperCase()} · $_audioBitrate kbps';
      final entry = DownloadHistoryEntry(
        title: video.title,
        filePath: finalPath ?? outputDir,
        mode: _mode == DownloadMode.video ? 'Video' : 'Audio',
        detail: detail,
        completedAt: DateTime.now(),
      );
      await _historyStore.add(entry);
      await _loadHistory();
    } on YtDownloadCancelled {
      // user cancelled; nothing to report
    } on YtDlpException catch (e) {
      if (mounted) setState(() => _downloadError = e.message);
    } catch (_) {
      if (mounted) setState(() => _downloadError = 'Download failed.');
    } finally {
      _activeDownload = null;
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = null;
        });
      }
    }
  }

  void _cancelDownload() {
    _activeDownload?.cancel();
  }

  Future<void> _openFolder(String filePath) async {
    if (!Platform.isWindows) return;
    final dir = File(filePath).parent.path;
    await Process.run('explorer', [dir]);
  }

  @override
  Widget build(BuildContext context) {
    if (_stage == _Stage.settingUp) return _buildSetup(context);
    return _buildReady(context);
  }

  Widget _buildSetup(BuildContext context) {
    final luma = context.luma;
    final frac = _setupProgress?.fraction;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_rounded, color: luma.accent, size: 40),
            const SizedBox(height: 16),
            Text(
              'Setting up YouTube Downloader',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _setupError ??
                  (_setupProgress?.status ??
                      'Fetching yt-dlp and ffmpeg — this only happens once.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_setupError == null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 6,
                  backgroundColor: luma.border,
                  valueColor: AlwaysStoppedAnimation(luma.accent),
                ),
              )
            else
              LumaPrimaryButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onTap: _setupTools,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReady(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LumaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Download a video',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paste a YouTube link to get started.',
                      style: TextStyle(color: luma.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: TextStyle(color: luma.textPrimary),
                            decoration: _inputDecoration(luma,
                                hint: 'https://www.youtube.com/watch?v=...'),
                            onSubmitted: (_) => _fetch(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        LumaPrimaryButton(
                          label: 'Fetch',
                          icon: Icons.search_rounded,
                          loading: _fetching,
                          onTap: _fetch,
                        ),
                      ],
                    ),
                    if (_fetchError != null) ...[
                      const SizedBox(height: 8),
                      Text(_fetchError!,
                          style: TextStyle(color: luma.danger, fontSize: 13)),
                    ],
                    if (_video != null) ...[
                      const SizedBox(height: 16),
                      _buildVideoCard(luma, _video!),
                      const SizedBox(height: 16),
                      _buildOptions(luma),
                      const SizedBox(height: 16),
                      _buildOutputRow(luma),
                      const SizedBox(height: 16),
                      if (_downloading)
                        _buildDownloadProgress(luma)
                      else
                        LumaPrimaryButton(
                          label: 'Download',
                          icon: Icons.download_rounded,
                          expand: true,
                          onTap: _download,
                        ),
                      if (_downloadError != null) ...[
                        const SizedBox(height: 8),
                        Text(_downloadError!,
                            style:
                                TextStyle(color: luma.danger, fontSize: 13)),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'History',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: LumaEmptyState(
                    icon: Icons.download_rounded,
                    title: 'Nothing downloaded yet',
                    subtitle: 'Completed downloads show up here.',
                  ),
                )
              else
                Column(
                  children: [
                    for (final entry in _history) ...[
                      _HistoryCard(
                        entry: entry,
                        onOpen: () => _openFolder(entry.filePath),
                        onDelete: () async {
                          await _historyStore.remove(entry);
                          await _loadHistory();
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(LumaPalette luma, YtVideoInfo video) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: video.thumbnail != null
              ? Image.network(
                  video.thumbnail!,
                  width: 120,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 120,
                    height: 68,
                    color: luma.background,
                  ),
                )
              : Container(width: 120, height: 68, color: luma.background),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (video.uploader != null) video.uploader!,
                  if (video.durationSeconds != null)
                    _formatDuration(video.durationSeconds!),
                ].join(' · '),
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptions(LumaPalette luma) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LumaSegmentedTabs(
          tabs: const ['Video', 'Audio only'],
          selectedIndex: _mode == DownloadMode.video ? 0 : 1,
          onSelect: (i) =>
              setState(() => _mode = i == 0 ? DownloadMode.video : DownloadMode.audio),
        ),
        const SizedBox(height: 14),
        if (_mode == DownloadMode.video) ...[
          _dropdownRow(
            luma,
            label: 'Resolution',
            value: _videoHeight,
            items: _availableOrAllHeights(),
            labelFor: (h) => '${h}p',
            onChanged: (v) => setState(() => _videoHeight = v),
          ),
          const SizedBox(height: 10),
          _dropdownRow(
            luma,
            label: 'Audio bitrate',
            value: _videoAudioBitrate,
            items: _bitrates,
            labelFor: (b) => '$b kbps',
            onChanged: (v) => setState(() => _videoAudioBitrate = v!),
          ),
        ] else ...[
          _dropdownRow(
            luma,
            label: 'Format',
            value: _audioFormat,
            items: _audioFormats,
            labelFor: (f) => f.toUpperCase(),
            onChanged: (v) => setState(() => _audioFormat = v!),
          ),
          const SizedBox(height: 10),
          _dropdownRow(
            luma,
            label: 'Bitrate',
            value: _audioBitrate,
            items: _bitrates,
            labelFor: (b) => '$b kbps',
            onChanged: (v) => setState(() => _audioBitrate = v!),
          ),
        ],
      ],
    );
  }

  List<int> _availableOrAllHeights() {
    final available = _video?.availableHeights ?? const <int>[];
    if (available.isEmpty) return _videoQualities;
    final set = available.toSet();
    return _videoQualities.where(set.contains).toList()
      ..sort((a, b) => b.compareTo(a));
  }

  Widget _dropdownRow<T>(
    LumaPalette luma, {
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelFor,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(color: luma.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: luma.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: luma.surface,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                items: [
                  for (final item in items)
                    DropdownMenuItem(value: item, child: Text(labelFor(item))),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutputRow(LumaPalette luma) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text('Save to',
              style: TextStyle(color: luma.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            _outputDir ?? 'Choose a folder…',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: luma.textMuted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        LumaGhostButton(
          label: 'Browse',
          icon: Icons.folder_open_rounded,
          onTap: _chooseOutputDir,
        ),
      ],
    );
  }

  Widget _buildDownloadProgress(LumaPalette luma) {
    final p = _progress;
    final percent = p?.percent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percent != null ? percent / 100 : null,
            minHeight: 8,
            backgroundColor: luma.border,
            valueColor: AlwaysStoppedAnimation(luma.accent),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                percent != null
                    ? '${percent.toStringAsFixed(1)}%'
                        '${p?.speed != null ? ' · ${p!.speed}' : ''}'
                        '${p?.eta != null ? ' · ETA ${p!.eta}' : ''}'
                    : (p?.rawLine ?? 'Working…'),
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ),
            LumaGhostButton(
              label: 'Cancel',
              icon: Icons.close_rounded,
              onTap: _cancelDownload,
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.onOpen,
    required this.onDelete,
  });

  final DownloadHistoryEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          LumaIconBadge(
            icon: entry.mode == 'Video'
                ? Icons.movie_outlined
                : Icons.music_note_outlined,
            color: luma.accent,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.mode} · ${entry.detail}',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.folder_open_rounded,
                color: luma.textMuted, size: 20),
            tooltip: 'Open folder',
            onPressed: onOpen,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded,
                color: luma.textMuted, size: 20),
            tooltip: 'Remove from history',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(LumaPalette luma, {String? hint}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted),
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}
