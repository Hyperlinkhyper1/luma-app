import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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
      title: json['title']?.toString() ?? 'Untitled',
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
/// YouTube Downloader plugin. Nothing is bundled with the app: on first use
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
      onProgress(ToolSetupProgress('Downloading yt-dlp…', fraction: 0));
      await _downloadFile(_ytDlpUrl, ytDlpFile, (frac) {
        onProgress(ToolSetupProgress('Downloading yt-dlp…', fraction: frac));
      });
      if (!_isWindows) {
        await Process.run('chmod', ['+x', await _ytDlpPath]);
      }
    }

    if (_isWindows) {
      final ffmpegFile = File(await _ffmpegPath);
      if (!await ffmpegFile.exists()) {
        onProgress(ToolSetupProgress('Downloading ffmpeg…', fraction: 0));
        final zipBytes = await _downloadBytes(_ffmpegZipUrl, (frac) {
          onProgress(ToolSetupProgress('Downloading ffmpeg…', fraction: frac));
        });
        onProgress(ToolSetupProgress('Extracting ffmpeg…', fraction: null));
        final archive = ZipDecoder().decodeBytes(zipBytes);
        ArchiveFile? ffmpegEntry;
        for (final entry in archive) {
          if (entry.isFile && entry.name.toLowerCase().endsWith('/ffmpeg.exe')) {
            ffmpegEntry = entry;
            break;
          }
        }
        if (ffmpegEntry == null) {
          throw YtDlpException('Could not find ffmpeg.exe inside the download.');
        }
        await ffmpegFile.writeAsBytes(ffmpegEntry.content as List<int>);
      }
    } else {
      if (!await _ffmpegOnPath) {
        throw YtDlpException(
          'ffmpeg was not found on your PATH. Install it via your package '
          'manager (e.g. sudo apt install ffmpeg) and try again.',
        );
      }
    }

    onProgress(ToolSetupProgress('Ready', fraction: 1));
  }

  /// Re-downloads yt-dlp even if present, to pick up fixes for YouTube's
  /// frequent breakage. Does not touch ffmpeg.
  Future<void> updateYtDlp(void Function(ToolSetupProgress) onProgress) async {
    final file = File(await _ytDlpPath);
    onProgress(ToolSetupProgress('Updating yt-dlp…', fraction: 0));
    await _downloadFile(_ytDlpUrl, file, (frac) {
      onProgress(ToolSetupProgress('Updating yt-dlp…', fraction: frac));
    });
    if (!_isWindows) {
      await Process.run('chmod', ['+x', await _ytDlpPath]);
    }
    onProgress(ToolSetupProgress('Ready', fraction: 1));
  }

  Future<void> _downloadFile(
      String url, File dest, void Function(double) onFraction) async {
    final bytes = await _downloadBytes(url, onFraction);
    await dest.writeAsBytes(bytes);
  }

  Future<List<int>> _downloadBytes(
      String url, void Function(double) onFraction) async {
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      final res = await client.send(req);
      if (res.statusCode != 200) {
        throw YtDlpException(
            'Download failed (${res.statusCode}) for $url.');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final chunks = <List<int>>[];
      await for (final chunk in res.stream) {
        chunks.add(chunk);
        received += chunk.length;
        if (total > 0) onFraction(received / total);
      }
      return chunks.expand((c) => c).toList(growable: false);
    } on YtDlpException {
      rethrow;
    } catch (_) {
      throw YtDlpException('Could not reach $url. Check your connection.');
    } finally {
      client.close();
    }
  }

  Future<YtVideoInfo> fetchInfo(String url) async {
    if (!await toolsReady) {
      throw YtDlpException('Tools are not set up yet.');
    }
    final result = await Process.run(
      await _ytDlpPath,
      ['-j', '--no-playlist', '--no-warnings', url],
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
      throw YtDlpException('Could not read video info.');
    }
    try {
      return YtVideoInfo.fromJson(jsonDecode(line) as Map<String, dynamic>);
    } catch (_) {
      throw YtDlpException('Could not parse video info.');
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
        throw YtDlpException('Tools are not set up yet.');
      }
      final outputTemplate =
          '$outputDir${Platform.pathSeparator}%(title)s [%(id)s].%(ext)s';

      final args = <String>[
        url,
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

  String _cleanError(String stderr) {
    final lines = stderr
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('ERROR:'))
        .toList();
    if (lines.isEmpty) {
      return stderr.trim().isEmpty
          ? 'yt-dlp failed for an unknown reason.'
          : stderr.trim().split('\n').last;
    }
    return lines.first.replaceFirst('ERROR:', '').trim();
  }
}
