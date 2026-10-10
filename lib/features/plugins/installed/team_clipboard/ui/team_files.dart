import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../l10n/current_l.dart';
import '../../../../../theme/luma_theme.dart';
import '../team_clipboard_controller.dart';
import '../team_clipboard_models.dart';
import '../team_clipboard_scope.dart';
import '../team_file_check.dart';
import 'team_clipboard_style.dart';

/// Lets the user pick files to attach, and checks each one here, before
/// anything is sent: the same rules the server applies (see
/// [checkTeamFile]). Files that fail are left out and named, with the
/// reason, in [rejected].
Future<({List<TeamPickedFile> files, List<String> rejected})?> pickTeamFiles(
  L t,
) async {
  final picked = await FilePicker.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: kTeamFileExtensions,
  );
  if (picked == null) return null;
  final files = <TeamPickedFile>[];
  final rejected = <String>[];
  for (final f in picked.files) {
    final early = teamFileStructureProblem(f.name, Uint8List(0));
    if (early?.kind == TeamFileProblemKind.wrongType) {
      rejected.add(early!.describe(t, f.name));
      continue;
    }
    if (f.size > kTeamMaxFileBytes) {
      rejected.add(t.teamClipboardFileTooLarge(f.name));
      continue;
    }
    final Uint8List bytes;
    try {
      bytes = f.bytes ?? await File(f.path!).readAsBytes();
    } catch (_) {
      rejected.add('${f.name}: ${t.teamClipboardCouldNotLoad}');
      continue;
    }
    final problem = await checkTeamFile(f.name, bytes);
    if (problem != null) {
      rejected.add(problem.describe(t, f.name));
      continue;
    }
    files.add(TeamPickedFile(f.name, bytes));
  }
  return (files: files, rejected: rejected);
}

/// Saves one file where the user picks.
Future<String?> saveTeamFile(
  TeamClipboardController controller,
  TeamFile file,
) async {
  final bytes = await controller.file(file.id);
  if (bytes == null) throw Exception(currentL.teamClipboardCouldNotLoad);
  final mobile = Platform.isAndroid || Platform.isIOS;
  final target = await FilePicker.saveFile(
    fileName: file.name,
    bytes: mobile ? bytes : null,
  );
  if (target != null && !mobile) {
    await File(target).writeAsBytes(bytes, flush: true);
  }
  return target;
}

/// Saves every file of an entry into one folder the user picks. Desktop
/// only: a phone's folder picker hands back a location apps can't write to.
Future<(String, int)?> saveAllTeamFiles(
  TeamClipboardController controller,
  TeamEntry entry,
) async {
  final dir = await FilePicker.getDirectoryPath();
  if (dir == null) return null;
  var saved = 0;
  for (final file in entry.files) {
    final bytes = await controller.file(file.id);
    if (bytes == null) continue;
    await File(
      '$dir${Platform.pathSeparator}${file.name}',
    ).writeAsBytes(bytes, flush: true);
    saved++;
  }
  return (dir, saved);
}

bool get teamCanSaveAll => !(Platform.isAndroid || Platform.isIOS);

/// Draws [image] pixel-sharp, showing only [frame] of an animated strip.
class _TexturePainter extends CustomPainter {
  _TexturePainter(this.image, this.frame, this.frames);

  final ui.Image image;
  final int frame;
  final int frames;

  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width.toDouble();
    final h = image.height / frames;
    final src = Rect.fromLTWH(0, h * frame, w, h);
    final scale = (size.width / w) < (size.height / h)
        ? size.width / w
        : size.height / h;
    final dst = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: w * scale,
      height: h * scale,
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_TexturePainter old) =>
      old.image != image || old.frame != frame;
}

/// A texture on a checkerboard. With [animate] an animated strip plays at
/// [frameTime]; otherwise its first frame stands still.
class TeamTexture extends StatefulWidget {
  const TeamTexture({
    super.key,
    required this.bytes,
    this.animate = false,
    this.frameTime = const Duration(milliseconds: 50),
    this.cell = 6,
  });

  final Uint8List bytes;
  final bool animate;
  final Duration frameTime;
  final double cell;

  @override
  State<TeamTexture> createState() => _TeamTextureState();
}

class _TeamTextureState extends State<TeamTexture> {
  ui.Image? _image;
  bool _failed = false;
  int _frame = 0;
  Timer? _timer;

  int get _frames =>
      _image == null ? 1 : teamTextureFrames(_image!.width, _image!.height);

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(TeamTexture old) {
    super.didUpdateWidget(old);
    if (!identical(old.bytes, widget.bytes)) {
      _decode();
    } else if (old.frameTime != widget.frameTime) {
      _startTimer();
    }
  }

  Future<void> _decode() async {
    try {
      final image = await decodeImageFromList(widget.bytes);
      if (!mounted) return;
      setState(() {
        _image?.dispose();
        _image = image;
        _frame = 0;
      });
      _startTimer();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.animate || _frames < 2) return;
    _timer = Timer.periodic(widget.frameTime, (_) {
      if (mounted) setState(() => _frame = (_frame + 1) % _frames);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: TeamCheckerboard(
        dark ? const Color(0xFF2A2633) : const Color(0xFFF2EFF8),
        dark ? const Color(0xFF221F2A) : const Color(0xFFE4DFEE),
        cell: widget.cell,
      ),
      child: _image != null
          ? CustomPaint(
              painter: _TexturePainter(_image!, _frame, _frames),
              size: Size.infinite,
            )
          : Center(
              child: _failed
                  ? Icon(Icons.broken_image_rounded, color: luma.textMuted)
                  : const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
    );
  }
}

/// One attached file: a texture thumbnail or a model/metadata icon, its
/// name, size and uploader, and save/remove buttons. Tapping opens a
/// preview.
class TeamFileTile extends StatefulWidget {
  const TeamFileTile({
    super.key,
    required this.entry,
    required this.file,
    required this.onRemove,
  });

  final TeamEntry entry;
  final TeamFile file;
  final VoidCallback? onRemove;

  @override
  State<TeamFileTile> createState() => _TeamFileTileState();
}

class _TeamFileTileState extends State<TeamFileTile> {
  bool _hover = false;
  Future<Uint8List?>? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.file.isImage) {
      _bytes ??= TeamClipboardScope.read(context).file(widget.file.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final file = widget.file;
    final controller = TeamClipboardScope.read(context);
    return Semantics(
      button: true,
      label: file.name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => showTeamFilePreview(context, widget.entry, file),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 168,
            decoration: BoxDecoration(
              color: _hover ? luma.surfaceHover : luma.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hover
                    ? luma.accent.withValues(alpha: 0.5)
                    : luma.border,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 96,
                  child: file.isImage
                      ? FutureBuilder<Uint8List?>(
                          future: _bytes,
                          builder: (context, snap) {
                            final bytes =
                                snap.data ?? controller.cachedFile(file.id);
                            if (bytes != null) return TeamTexture(bytes: bytes);
                            return Container(
                              color: luma.background,
                              alignment: Alignment.center,
                              child:
                                  snap.connectionState == ConnectionState.done
                                  ? Icon(
                                      Icons.broken_image_rounded,
                                      color: luma.textMuted,
                                    )
                                  : const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                            );
                          },
                        )
                      : Container(
                          color: luma.background,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                file.extension == 'mcmeta'
                                    ? Icons.animation_rounded
                                    : Icons.data_object_rounded,
                                color: luma.accent,
                                size: 30,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '.${file.extension}',
                                style: TextStyle(
                                  color: luma.textMuted,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tooltip(
                              message: file.name,
                              child: Text(
                                file.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: luma.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.teamClipboardFileBy(
                                teamFileSize(file.sizeBytes),
                                teamPerson(t, file.uploader),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: luma.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TileButton(
                        icon: Icons.download_rounded,
                        tooltip: t.commonDownload,
                        onTap: () => _save(context, controller),
                      ),
                      if (widget.onRemove != null)
                        _TileButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: t.teamClipboardRemoveFile,
                          color: luma.danger,
                          onTap: widget.onRemove!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    TeamClipboardController controller,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final t = L.of(context);
    try {
      final path = await saveTeamFile(controller, widget.file);
      if (path != null) {
        messenger?.showSnackBar(
          SnackBar(content: Text(t.teamClipboardSavedTo(path))),
        );
      }
    } catch (_) {
      messenger?.showSnackBar(
        SnackBar(content: Text(t.teamClipboardCouldNotLoad)),
      );
    }
  }
}

class _TileButton extends StatelessWidget {
  const _TileButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    color: color ?? context.luma.textSecondary,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    padding: EdgeInsets.zero,
  );
}

/// A big preview: a texture zoomed in (animated when it's a strip, at the
/// frametime its `.mcmeta` sets), or a model's JSON, pretty-printed and
/// copyable.
Future<void> showTeamFilePreview(
  BuildContext context,
  TeamEntry entry,
  TeamFile file,
) {
  final controller = TeamClipboardScope.read(context);
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _FilePreviewDialog(controller: controller, entry: entry, file: file),
  );
}

class _FilePreviewDialog extends StatefulWidget {
  const _FilePreviewDialog({
    required this.controller,
    required this.entry,
    required this.file,
  });

  final TeamClipboardController controller;
  final TeamEntry entry;
  final TeamFile file;

  @override
  State<_FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<_FilePreviewDialog> {
  late final Future<Uint8List?> _bytes = widget.controller.file(widget.file.id);
  Duration _frameTime = const Duration(milliseconds: 50);
  int? _frames;

  @override
  void initState() {
    super.initState();
    if (widget.file.isImage) _readFrameTime();
  }

  /// `ruby.png` animates by `ruby.png.mcmeta`; its frametime is in ticks.
  Future<void> _readFrameTime() async {
    final meta = widget.entry.files
        .where(
          (f) =>
              f.name.toLowerCase() ==
              '${widget.file.name.toLowerCase()}.mcmeta',
        )
        .firstOrNull;
    if (meta == null) return;
    final bytes = await widget.controller.file(meta.id);
    if (bytes == null) return;
    try {
      final json = jsonDecode(utf8.decode(bytes));
      final animation = json is Map ? json['animation'] : null;
      final ticks = animation is Map ? animation['frametime'] : null;
      if (ticks is int && ticks > 0 && mounted) {
        setState(() => _frameTime = Duration(milliseconds: ticks * 50));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final file = widget.file;
    return Dialog(
      backgroundColor: luma.surface,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Uint8List?>(
            future: _bytes,
            builder: (context, snap) {
              final bytes = snap.data;
              final text = bytes == null || file.isImage
                  ? null
                  : _pretty(utf8.decode(bytes, allowMalformed: true));
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          file.name,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (text != null)
                        IconButton(
                          tooltip: t.commonCopy,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          color: luma.textSecondary,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(content: Text(t.commonCopied)),
                            );
                          },
                        ),
                      IconButton(
                        tooltip: t.commonClose,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        color: luma.textSecondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Text(
                    [
                      teamFileSize(file.sizeBytes),
                      teamPerson(t, file.uploader),
                      if ((_frames ?? 1) > 1) t.teamClipboardFrames(_frames!),
                    ].join(' · '),
                    style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: switch (snap.connectionState) {
                      ConnectionState.done when bytes == null => Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          t.teamClipboardCouldNotLoad,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: luma.textSecondary),
                        ),
                      ),
                      ConnectionState.done when file.isImage => AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _FrameCounter(
                            bytes: bytes!,
                            onFrames: (n) {
                              if (_frames != n) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) setState(() => _frames = n);
                                });
                              }
                            },
                            child: TeamTexture(
                              bytes: bytes,
                              animate: true,
                              frameTime: _frameTime,
                              cell: 16,
                            ),
                          ),
                        ),
                      ),
                      ConnectionState.done => Container(
                        decoration: BoxDecoration(
                          color: luma.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: luma.border),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(14),
                          child: SelectableText(
                            text ?? '',
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontFamily: 'monospace',
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ),
                      _ => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _pretty(String raw) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }
}

/// Reads a texture's frame count once, for the dialog's caption.
class _FrameCounter extends StatefulWidget {
  const _FrameCounter({
    required this.bytes,
    required this.onFrames,
    required this.child,
  });

  final Uint8List bytes;
  final ValueChanged<int> onFrames;
  final Widget child;

  @override
  State<_FrameCounter> createState() => _FrameCounterState();
}

class _FrameCounterState extends State<_FrameCounter> {
  @override
  void initState() {
    super.initState();
    () async {
      try {
        final image = await decodeImageFromList(widget.bytes);
        widget.onFrames(teamTextureFrames(image.width, image.height));
        image.dispose();
      } catch (_) {}
    }();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
