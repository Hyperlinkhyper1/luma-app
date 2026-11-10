import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../../l10n/current_l.dart';
import '../../../../security/guarded_download.dart';

/// The web address to hand yt-dlp for what the user pasted, or null when it
/// is not one. yt-dlp reads anything starting with a dash as one of its own
/// options, `--exec` among them, so only an http(s) address gets through; a
/// link pasted without its scheme is taken as https.
String? normalizeMediaUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty ||
      trimmed.startsWith('-') ||
      RegExp(r'[\s\x00-\x1F\x7F]').hasMatch(trimmed)) {
    return null;
  }
  final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(candidate);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      uri.host.isEmpty) {
    return null;
  }
  return candidate;
}

/// Metadata about a YouTube video, as reported by yt-dlp's `-j` (dump-json).
class YtVideoInfo {
  YtVideoInfo({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.durationSeconds,
    required this.uploader,
    required this.availableHeights,
  });

  final String id;
  final String title;
  final String? thumbnail;
  final int? durationSeconds;
  final String? uploader;

  /// Distinct video-track heights (e.g. 360, 720, 1080) that yt-dlp reports
  /// as available for this video, sorted ascending.
  final List<int> availableHeights;

  factory YtVideoInfo.fromJson(Map<String, dynamic> json) {
    final heights = <int>{};
    final formats = json['formats'];
    if (formats is List) {
      for (final f in formats) {
        if (f is Map && f['height'] is int) {
          heights.add(f['height'] as int);
        }
      }
    }
    final list = heights.toList()..sort();
    return YtVideoInfo(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? currentL.commonUntitled,
      thumbnail: json['thumbnail']?.toString(),
      durationSeconds: json['duration'] is num
          ? (json['duration'] as num).round()
          : null,
      uploader: json['uploader']?.toString() ?? json['channel']?.toString(),
      availableHeights: list,
    );
  }
}

enum DownloadMode { video, audio }

class _ResolvedSource {
  _ResolvedSource(this.url, {this.id, this.title, this.thumbnail});
  final String url;
  final String? id;
  final String? title;
  final String? thumbnail;
}

class _ProcessHolder {
  Process? process;
  bool cancelled = false;
}

class YtDownloadHandle {
  YtDownloadHandle({required this.progress, required this.cancel});
  final Stream<DownloadProgress> progress;
  final void Function() cancel;
}

class YtDownloadCancelled implements Exception {}

class DownloadProgress {
  DownloadProgress({
    this.percent,
    this.speed,
    this.eta,
    required this.rawLine,
    this.done = false,
  });

  final double? percent;
  final String? speed;
  final String? eta;
  final String rawLine;
  final bool done;
}

class ToolSetupProgress {
  ToolSetupProgress(this.status, {this.fraction});
  final String status;
  final double? fraction;
}

class YtDlpException implements Exception {
  YtDlpException(this.message);
  final String message;
  @override
  String toString() => message;
}
/// Downloads, locates, and drives the yt-dlp / ffmpeg binaries used by the
/// Media Downloader plugin. Nothing is bundled with the app: on first use
/// the current yt-dlp binary is pulled from its GitHub release and (on
/// Windows) a static ffmpeg build is pulled and unzipped, both cached under
/// the app's support directory so this only happens once. On Linux ffmpeg is
/// expected on the system PATH (install via package manager).
class YtDlpManager {
  YtDlpManager._();
  static final YtDlpManager instance = YtDlpManager._();

  static bool get _isWindows => Platform.isWindows;

  static String get _ytDlpExe => _isWindows ? 'yt-dlp.exe' : 'yt-dlp';
  static String get _ffmpegExe => _isWindows ? 'ffmpeg.exe' : 'ffmpeg';

  static String get _ytDlpUrl => _isWindows
      ? 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
      : 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';
  static const _ffmpegZipUrl =
      'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip';

  static const _maxYtDlpBytes = 256 * 1024 * 1024;
  static const _maxFfmpegZipBytes = 512 * 1024 * 1024;

  Future<Directory> _toolsDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}tools');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> get _ytDlpPath async =>
      '${(await _toolsDir()).path}${Platform.pathSeparator}$_ytDlpExe';
  Future<String> get _ffmpegPath async =>
      '${(await _toolsDir()).path}${Platform.pathSeparator}$_ffmpegExe';

  Future<bool> get toolsReady async {
    final ytDlpExists = await File(await _ytDlpPath).exists();
    if (!ytDlpExists) return false;
    if (_isWindows) {
      return File(await _ffmpegPath).exists();
    }
    return _ffmpegOnPath;
  }

  Future<bool> get _ffmpegOnPath async {
    try {
      final result = await Process.run(_ffmpegExe, const ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Downloads whichever of yt-dlp / ffmpeg are missing, reporting progress.
  Future<void> ensureTools(void Function(ToolSetupProgress) onProgress) async {
    final ytDlpFile = File(await _ytDlpPath);

    if (!await ytDlpFile.exists()) {
      onProgress(ToolSetupProgress(currentL.mediaDlStatusDownloadingYtDlp, fraction: 0));
      await _downloadFile(_ytDlpUrl, ytDlpFile, _maxYtDlpBytes, (frac) {
        onProgress(ToolSetupProgress(currentL.mediaDlStatusDownloadingYtDlp, fraction: frac));
      });
      if (!_isWindows) {
        await Process.run('chmod', ['+x', await _ytDlpPath]);
      }
    }

    if (_isWindows) {
      final ffmpegFile = File(await _ffmpegPath);
      if (!await ffmpegFile.exists()) {
        onProgress(ToolSetupProgress(currentL.mediaDlStatusDownloadingFfmpeg, fraction: 0));
        final zipBytes =
            await _downloadBytes(_ffmpegZipUrl, _maxFfmpegZipBytes, (frac) {
          onProgress(ToolSetupProgress(currentL.mediaDlStatusDownloadingFfmpeg, fraction: frac));
        });
        onProgress(ToolSetupProgress(currentL.mediaDlStatusExtractingFfmpeg, fraction: null));
        final archive = ZipDecoder().decodeBytes(zipBytes);
        ArchiveFile? ffmpegEntry;
        for (final entry in archive) {
          if (entry.isFile && entry.name.toLowerCase().endsWith('/ffmpeg.exe')) {
            ffmpegEntry = entry;
            break;
          }
        }
        if (ffmpegEntry == null) {
          throw YtDlpException(currentL.mediaDlFfmpegNotInDownload);
        }
        await _replaceFile(ffmpegFile, ffmpegEntry.content as List<int>);
      }
    } else {
      if (!await _ffmpegOnPath) {
        throw YtDlpException(currentL.mediaDlFfmpegNotOnPath);
      }
    }

    onProgress(ToolSetupProgress(currentL.mediaDlStatusReady, fraction: 1));
  }

  /// Re-downloads yt-dlp even if present, to pick up fixes for YouTube's
  /// frequent breakage. Does not touch ffmpeg.
  Future<void> updateYtDlp(void Function(ToolSetupProgress) onProgress) async {
    final file = File(await _ytDlpPath);
    onProgress(ToolSetupProgress(currentL.mediaDlStatusUpdatingYtDlp, fraction: 0));
    await _downloadFile(_ytDlpUrl, file, _maxYtDlpBytes, (frac) {
      onProgress(ToolSetupProgress(currentL.mediaDlStatusUpdatingYtDlp, fraction: frac));
    });
    if (!_isWindows) {
      await Process.run('chmod', ['+x', await _ytDlpPath]);
    }
    onProgress(ToolSetupProgress(currentL.mediaDlStatusReady, fraction: 1));
  }

  Future<void> _downloadFile(String url, File dest, int maxBytes,
      void Function(double) onFraction) async {
    await _replaceFile(dest, await _downloadBytes(url, maxBytes, onFraction));
  }

  /// Written beside [dest] and moved into place, so a download that dies
  /// halfway never leaves a truncated executable where the real one goes.
  Future<void> _replaceFile(File dest, List<int> bytes) async {
    final part = File('${dest.path}.part');
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(dest.path);
  }

  Future<Uint8List> _downloadBytes(
      String url, int maxBytes, void Function(double) onFraction) async {
    try {
      return await guardedDownload(
        Uri.parse(url),
        maxBytes: maxBytes,
        onProgress: (received, total) {
          if (total != null && total > 0) onFraction(received / total);
        },
      );
    } on GuardedDownloadException catch (e) {
      if (e.failure == GuardedDownloadFailure.status) {
        throw YtDlpException(
            currentL.mediaDlHttpFailed('${e.statusCode}', url));
      }
      throw YtDlpException(currentL.mediaDlCouldNotReach(url));
    } catch (_) {
      throw YtDlpException(currentL.mediaDlCouldNotReach(url));
    }
  }

  static final _regionalEpisode = RegExp(
      r'^https?://(?:www\.)?omroepwest\.nl/tv/aflevering/[^/?#]+/(\d+)',
      caseSensitive: false);

  Future<_ResolvedSource> _resolve(String input) async {
    final url = normalizeMediaUrl(input);
    if (url == null) throw YtDlpException(currentL.mediaDlCouldNotReadLink);
    final m = _regionalEpisode.firstMatch(url);
    if (m == null) return _ResolvedSource(url);
    final id = m.group(1)!;
    final stream =
        'https://omroepwest.bbvms.com/mediaclip/srcid:$id/redirect/MP4_HLS';
    String? title;
    String? thumbnail;
    try {
      final res = await http
          .get(Uri.parse(url), headers: const {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final html = utf8.decode(res.bodyBytes, allowMalformed: true);
        title = _metaContent(html, 'og:title')
            ?.replaceFirst(RegExp(r'\s*-\s*Omroep West\s*$'), '');
        thumbnail = _metaContent(html, 'og:image');
      }
    } catch (_) {}
    return _ResolvedSource(stream, id: id, title: title, thumbnail: thumbnail);
  }

  static String? _metaContent(String html, String property) {
    final m = RegExp('property="${RegExp.escape(property)}"\\s+content="([^"]*)"')
        .firstMatch(html);
    final raw = m?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  static String _safeFileName(String name) => name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll('%', '%%')
      .trim();

  Future<YtVideoInfo> fetchInfo(String url) async {
    if (!await toolsReady) {
      throw YtDlpException(currentL.mediaDlToolsNotReady);
    }
    final source = await _resolve(url);
    final result = await Process.run(
      await _ytDlpPath,
      ['-j', '--no-playlist', '--no-warnings', '--', source.url],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw YtDlpException(_cleanError(result.stderr.toString()));
    }
    final line = (result.stdout as String)
        .split('\n')
        .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    if (line.isEmpty) {
      throw YtDlpException(currentL.mediaDlCouldNotReadInfo);
    }
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      if (source.id != null) json['id'] = source.id;
      if (source.title != null) json['title'] = source.title;
      if (source.thumbnail != null) json['thumbnail'] = source.thumbnail;
      return YtVideoInfo.fromJson(json);
    } catch (_) {
      throw YtDlpException(currentL.mediaDlCouldNotParseInfo);
    }
  }

  /// Starts a download and streams progress updates until the process exits.
  YtDownloadHandle download({
    required String url,
    required DownloadMode mode,
    required String outputDir,
    int? videoHeight,
    String audioFormat = 'mp3',
    int audioBitrateKbps = 192,
  }) {
    final controller = StreamController<DownloadProgress>();
    final processHolder = _ProcessHolder();
    unawaited(_runDownload(
      controller: controller,
      processHolder: processHolder,
      url: url,
      mode: mode,
      outputDir: outputDir,
      videoHeight: videoHeight,
      audioFormat: audioFormat,
      audioBitrateKbps: audioBitrateKbps,
    ));
    return YtDownloadHandle(
      progress: controller.stream,
      cancel: () {
        processHolder.cancelled = true;
        processHolder.process?.kill();
      },
    );
  }

  Future<void> _runDownload({
    required StreamController<DownloadProgress> controller,
    required _ProcessHolder processHolder,
    required String url,
    required DownloadMode mode,
    required String outputDir,
    int? videoHeight,
    required String audioFormat,
    required int audioBitrateKbps,
  }) async {
    try {
      if (!await toolsReady) {
        throw YtDlpException(currentL.mediaDlToolsNotReady);
      }
      final source = await _resolve(url);
      final baseName = source.id == null
          ? '%(title)s [%(id)s]'
          : '${_safeFileName(source.title ?? source.id!)} [${source.id}]';
      final outputTemplate =
          '$outputDir${Platform.pathSeparator}$baseName.%(ext)s';

      final args = <String>[
        if (_isWindows) ...['--ffmpeg-location', (await _toolsDir()).path],
        '--no-playlist',
        '--no-warnings',
        '--newline',
        '-o', outputTemplate,
      ];

      if (mode == DownloadMode.audio) {
        args.addAll([
          '-x',
          '--audio-format', audioFormat,
          '--audio-quality', '${audioBitrateKbps}K',
        ]);
      } else {
        final heightFilter = videoHeight != null ? '[height<=$videoHeight]' : '';
        args.addAll([
          '-f', 'bestvideo$heightFilter+bestaudio/best$heightFilter',
          '--merge-output-format', 'mp4',
          '--postprocessor-args', 'ffmpeg:-c:v copy -b:a ${audioBitrateKbps}k',
        ]);
      }
      args.addAll(['--', source.url]);

      final process = await Process.start(await _ytDlpPath, args);
      processHolder.process = process;
      String? destination;

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        final merged = RegExp(r'\[Merger\] Merging formats into "(.+)"')
                .firstMatch(line) ??
            RegExp(r'\[ExtractAudio\] Destination: (.+)').firstMatch(line) ??
            RegExp(r'\[download\] Destination: (.+)').firstMatch(line);
        if (merged != null) {
          destination = merged.group(1)?.trim().replaceAll('"', '');
        }
        controller.add(_parseProgressLine(line));
      });

      final errBuf = StringBuffer();
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(errBuf.writeln);

      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        if (processHolder.cancelled) throw YtDownloadCancelled();
        throw YtDlpException(_cleanError(errBuf.toString()));
      }
      controller.add(DownloadProgress(
        percent: 100,
        rawLine: destination ?? 'Done',
        done: true,
      ));
      await controller.close();
    } catch (e) {
      controller.addError(e);
      await controller.close();
    }
  }

  DownloadProgress _parseProgressLine(String line) {
    final m = RegExp(
      r'\[download\]\s+([\d.]+)% of\s+~?\s*([\d.]+\w+)\s+at\s+([\d.]+\w+/s|Unknown speed)\s+ETA\s+(\S+)',
    ).firstMatch(line);
    if (m == null) return DownloadProgress(rawLine: line);
    return DownloadProgress(
      percent: double.tryParse(m.group(1)!),
      speed: m.group(3),
      eta: m.group(4),
      rawLine: line,
    );
  }

  /// Rewrites an already-downloaded audio file's title/artist tags and
  /// (for mp3/m4a) embeds a cover image, via ffmpeg. Used after a
  /// Spotify-sourced download so the file carries the real track metadata
  /// instead of whatever the matched YouTube video was titled. Best-effort:
  /// on any failure the original file is left untouched.
  Future<void> tagAudioFile({
    required String filePath,
    required String title,
    String? artist,
    Uint8List? coverImageBytes,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final ext = filePath.split('.').last.toLowerCase();
    final supportsCover = ext == 'mp3' || ext == 'm4a';
    final ffmpeg = _isWindows ? await _ffmpegPath : _ffmpegExe;

    File? coverFile;
    if (supportsCover && coverImageBytes != null && coverImageBytes.isNotEmpty) {
      coverFile = File('$filePath.cover.jpg');
      await coverFile.writeAsBytes(coverImageBytes);
    }

    final tmpPath = '$filePath.tagged.$ext';
    final args = <String>['-y', '-i', filePath];
    if (coverFile != null) {
      args.addAll([
        '-i', coverFile.path,
        '-map', '0:a',
        '-map', '1:0',
        '-disposition:v', 'attached_pic',
      ]);
    }
    args.addAll(['-c', 'copy']);
    if (ext == 'mp3') args.addAll(['-id3v2_version', '3']);
    args.addAll(['-metadata', 'title=$title']);
    if (artist != null && artist.isNotEmpty) {
      args.addAll(['-metadata', 'artist=$artist']);
    }
    args.add(tmpPath);

    try {
      final result = await Process.run(ffmpeg, args);
      final tmpFile = File(tmpPath);
      if (result.exitCode == 0 && await tmpFile.exists()) {
        await file.delete();
        await tmpFile.rename(filePath);
      } else if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    } catch (_) {
      // Best-effort — leave the original file as downloaded.
    } finally {
      if (coverFile != null && await coverFile.exists()) {
        await coverFile.delete();
      }
    }
  }

  String _cleanError(String stderr) {
    final lines = stderr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('ERROR:'))
        .toList();
    if (lines.isEmpty) {
      return stderr.trim().isEmpty
          ? currentL.mediaDlYtDlpUnknownError
          : stderr.trim().split('\n').last;
    }
    return lines.first.replaceFirst('ERROR:', '').trim();
  }
}
