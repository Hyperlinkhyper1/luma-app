import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../office/assistant_workbench.dart';
import '../office/office_document.dart';
import '../office/office_export.dart' show sheetHasHeaderRow;
import 'chat_markdown.dart';

/// Below this width the chat has no room for a side panel, so files open
/// full screen instead.
const assistantFilePanelBreakpoint = 1000.0;

/// Shows [path] in luma's own preview: the side panel when the window is
/// wide enough, a full-screen page otherwise. Falls back to the system's
/// default app when no workbench is in scope.
Future<void> openAssistantFile(BuildContext context, String path) async {
  if (!await File(path).exists()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L.of(context).assistantPreviewNotFound)),
      );
    }
    return;
  }
  if (!context.mounted) return;
  final workbench = AssistantWorkbenchScope.maybeOf(context);
  if (workbench == null) {
    await openAssistantFileExternally(context, path);
    return;
  }
  await workbench.openPath(path);
  if (!context.mounted) return;
  if (MediaQuery.sizeOf(context).width < assistantFilePanelBreakpoint) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: AssistantFilePanel(
              workbench: workbench,
              onClose: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
    );
    workbench.close();
  }
}

/// Hands [path] to the system. When nothing is registered for its type
/// (ShellExecute's SE_ERR_NOASSOC, "HINSTANCE=31"), Windows is asked to show
/// its "Open with" chooser instead of failing.
Future<void> openAssistantFileExternally(
  BuildContext context,
  String path,
) async {
  final t = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  String? error;
  try {
    final result = await OpenFile.open(path);
    if (result.type != ResultType.done) {
      if (Platform.isWindows) {
        await Process.start('rundll32.exe', [
          'shell32.dll,OpenAs_RunDLL',
          path,
        ], mode: ProcessStartMode.detached);
      } else {
        error = result.type == ResultType.noAppToOpen
            ? t.assistantPreviewNoApp
            : result.message;
      }
    }
  } catch (failure) {
    error = '$failure';
  }
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
  }
}

Future<void> _showInFolder(String path) async {
  if (Platform.isWindows) {
    await Process.start('explorer.exe', [
      '/select,',
      path,
    ], mode: ProcessStartMode.detached);
  } else {
    await OpenFile.open(File(path).parent.path);
  }
}

/// The right-hand side panel's width for a window [available] wide.
double assistantFilePanelWidth(double available) =>
    (available * 0.42).clamp(380.0, 860.0);

/// The side panel slot in the wide chat layout: nothing until a file is
/// open, then [AssistantFilePanel] at [assistantFilePanelWidth].
class AssistantFilePanelSlot extends StatelessWidget {
  const AssistantFilePanelSlot({
    super.key,
    required this.workbench,
    required this.availableWidth,
  });
  final AssistantWorkbench workbench;
  final double availableWidth;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: workbench,
    builder: (context, _) {
      if (!workbench.hasFile || availableWidth < assistantFilePanelBreakpoint) {
        return const SizedBox.shrink();
      }
      return SizedBox(
        width: assistantFilePanelWidth(availableWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: context.luma.border)),
          ),
          child: AssistantFilePanel(
            workbench: workbench,
            onClose: workbench.close,
          ),
        ),
      );
    },
  );
}

/// The file preview: a header with the file and what the model is doing in
/// it, over a rendering of the file that follows every edit live.
class AssistantFilePanel extends StatelessWidget {
  const AssistantFilePanel({
    super.key,
    required this.workbench,
    required this.onClose,
  });
  final AssistantWorkbench workbench;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: workbench,
    builder: (context, _) {
      final file = workbench.file;
      final luma = context.luma;
      return ColoredBox(
        color: luma.background,
        child: file == null
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PanelHeader(
                    workbench: workbench,
                    file: file,
                    onClose: onClose,
                  ),
                  Divider(height: 1, color: luma.border),
                  Expanded(
                    child: _PanelBody(
                      key: ValueKey(file.path),
                      workbench: workbench,
                      file: file,
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

IconData _iconFor(AssistantPreviewFile file) => switch (file.officeKind) {
  OfficeKind.docx => Icons.description_outlined,
  OfficeKind.pptx => Icons.slideshow_outlined,
  OfficeKind.xlsx => Icons.grid_on_rounded,
  null => switch (file.extension) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'png' || 'jpg' || 'jpeg' || 'webp' || 'svg' => Icons.image_outlined,
    _ => Icons.insert_drive_file_outlined,
  },
};

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.workbench,
    required this.file,
    required this.onClose,
  });
  final AssistantWorkbench workbench;
  final AssistantPreviewFile file;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final textTheme = Theme.of(context).textTheme;
    final status = _statusText(context);
    final saveError = workbench.session?.saveError;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 6, 8),
      child: Row(
        children: [
          Icon(_iconFor(file), size: 18, color: luma.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (status != null || saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        if (saveError == null && workbench.modelActive) ...[
                          _PulseDot(color: luma.accent),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            saveError != null
                                ? t.assistantPreviewSaveError
                                : status!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: saveError != null
                                  ? luma.warning
                                  : luma.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.assistantPreviewOpenExternally,
            icon: Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: luma.textSecondary,
            ),
            onPressed: () => openAssistantFileExternally(context, file.path),
          ),
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            IconButton(
              tooltip: t.assistantPreviewShowInFolder,
              icon: Icon(
                Icons.folder_open_outlined,
                size: 18,
                color: luma.textSecondary,
              ),
              onPressed: () => _showInFolder(file.path),
            ),
          IconButton(
            tooltip: t.assistantPreviewClose,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: luma.textSecondary,
            ),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  String? _statusText(BuildContext context) {
    final t = L.of(context);
    final session = workbench.session;
    final focus = workbench.focus;
    if (!workbench.modelActive || session == null) return null;
    if (focus == null) return t.assistantPreviewWorking;
    if (focus.start < 0) return t.assistantPreviewReadingOutline;
    final part = _partLabel(context, session.document, focus);
    return switch (focus.activity) {
      OfficeActivity.reading => t.assistantPreviewReading(part),
      OfficeActivity.writing => t.assistantPreviewWriting(part),
      OfficeActivity.deleting => t.assistantPreviewDeleting(part),
    };
  }

  static String _partLabel(
    BuildContext context,
    OfficeDocument document,
    OfficeFocus focus,
  ) {
    final t = L.of(context);
    String range(int a, int? b) => b == null ? '${a + 1}' : '${a + 1}–${b + 1}';
    switch (document.kind) {
      case OfficeKind.docx:
        return t.assistantPreviewPartBlock(range(focus.start, focus.end));
      case OfficeKind.pptx:
        return t.assistantPreviewPartSlide(range(focus.start, focus.end));
      case OfficeKind.xlsx:
        final sheet = focus.start < document.sheets.length
            ? document.sheets[focus.start].name
            : '';
        final from = focus.cellStart;
        if (from == null) return sheet;
        final to = focus.cellEnd ?? from;
        final cells = from == to
            ? cellName(from.$1, from.$2)
            : '${cellName(from.$1, from.$2)}:${cellName(to.$1, to.$2)}';
        return '$sheet!$cells';
    }
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
    child: Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({super.key, required this.workbench, required this.file});
  final AssistantWorkbench workbench;
  final AssistantPreviewFile file;

  @override
  Widget build(BuildContext context) {
    final session = workbench.session;
    if (session != null) {
      final document = session.document;
      return switch (document.kind) {
        OfficeKind.docx => _WordView(
          document: document,
          focus: workbench.focus,
          revision: workbench.revision,
        ),
        OfficeKind.pptx => _SlidesView(
          document: document,
          focus: workbench.focus,
          revision: workbench.revision,
        ),
        OfficeKind.xlsx => _SheetView(
          document: document,
          focus: workbench.focus,
          revision: workbench.revision,
        ),
      };
    }
    return switch (file.extension) {
      'png' || 'jpg' || 'jpeg' || 'webp' => InteractiveViewer(
        maxScale: 6,
        child: Center(child: Image.file(File(file.path))),
      ),
      'svg' => InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SvgPicture.file(File(file.path)),
          ),
        ),
      ),
      'pdf' => _PdfView(path: file.path),
      'txt' ||
      'md' ||
      'csv' ||
      'json' ||
      'html' ||
      'xml' ||
      'log' => _TextView(path: file.path, markdown: file.extension == 'md'),
      _ => _Unsupported(file: file),
    };
  }
}

class _Unsupported extends StatelessWidget {
  const _Unsupported({required this.file});
  final AssistantPreviewFile file;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(file), size: 40, color: luma.textMuted),
            const SizedBox(height: 12),
            Text(
              t.assistantPreviewUnsupported,
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => openAssistantFileExternally(context, file.path),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(t.assistantPreviewOpenExternally),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ paper

/// Word and PDF pages are always white paper with dark ink, whatever the
/// app theme, like the documents they stand for.
const _paper = Color(0xffffffff);
const _ink = Color(0xff1f2937);
const _inkSoft = Color(0xff4b5563);
const _heading = Color(0xff1f3a5f);
const _rule = Color(0xffbfc7d5);
const _tableHead = Color(0xffe7eef8);

class _Paper extends StatelessWidget {
  const _Paper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        padding: const EdgeInsets.fromLTRB(44, 48, 44, 56),
        decoration: BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: _ink, fontSize: 14, height: 1.45),
          child: child,
        ),
      ),
    ),
  );
}

TextSpan _inlineSpan(String text, TextStyle style) => TextSpan(
  style: style,
  children: [
    for (final run in parseInline(text))
      TextSpan(
        text: run.text,
        style: TextStyle(
          fontWeight: run.bold ? FontWeight.w700 : null,
          fontStyle: run.italic ? FontStyle.italic : null,
        ),
      ),
  ],
);

/// Outlines the part the model is on, labelled with what it is doing, and
/// briefly tints parts that just changed.
class _FocusFrame extends StatelessWidget {
  const _FocusFrame({
    super.key,
    required this.focused,
    this.showTag = true,
    required this.activity,
    required this.child,
  });
  final bool focused;

  /// Only the first part of a range carries the label.
  final bool showTag;
  final OfficeActivity? activity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final color = activity == OfficeActivity.reading
        ? const Color(0xff0ea5e9)
        : luma.accent;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: focused ? color.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: focused
                  ? color.withValues(alpha: 0.85)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: child,
        ),
        if (focused && showTag && activity != null)
          PositionedDirectional(
            top: -9,
            end: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                switch (activity!) {
                  OfficeActivity.reading => t.assistantPreviewTagReading,
                  OfficeActivity.writing => t.assistantPreviewTagWriting,
                  OfficeActivity.deleting => t.assistantPreviewTagDeleting,
                },
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Keeps one key per part and scrolls the focused part into view whenever
/// the workbench revision moves on.
mixin _FollowsFocus<T extends StatefulWidget> on State<T> {
  final Map<int, GlobalKey> _keys = {};
  int _followedRevision = -1;

  GlobalKey keyFor(int index) => _keys.putIfAbsent(index, GlobalKey.new);

  void follow(int revision, OfficeFocus? focus) {
    if (revision == _followedRevision || focus == null || focus.start < 0) {
      return;
    }
    _followedRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _keys[focus.start]?.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.25,
        duration: MediaQuery.of(target).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _WordView extends StatefulWidget {
  const _WordView({
    required this.document,
    required this.focus,
    required this.revision,
  });
  final OfficeDocument document;
  final OfficeFocus? focus;
  final int revision;

  @override
  State<_WordView> createState() => _WordViewState();
}

class _WordViewState extends State<_WordView> with _FollowsFocus {
  @override
  Widget build(BuildContext context) {
    follow(widget.revision, widget.focus);
    final document = widget.document;
    final focus = widget.focus;
    final counters = <int>[0, 0, 0];
    var previous = DocBlockType.paragraph;
    final children = <Widget>[];
    for (final (i, block) in document.blocks.indexed) {
      if (block.type == DocBlockType.numbered) {
        if (previous != DocBlockType.numbered &&
            previous != DocBlockType.bullet) {
          counters.fillRange(0, 3, 0);
        }
        counters[block.level]++;
        for (var l = block.level + 1; l < 3; l++) {
          counters[l] = 0;
        }
      }
      previous = block.type;
      final focused = focus != null && focus.covers(i);
      children.add(
        Padding(
          padding: EdgeInsets.only(
            top: block.type == DocBlockType.heading ? 10 : 0,
            bottom: switch (block.type) {
              DocBlockType.bullet || DocBlockType.numbered => 3,
              _ => 9,
            },
          ),
          child: _FocusFrame(
            key: keyFor(i),
            focused: focused,
            activity: focused ? focus.activity : null,
            showTag: focused && i == focus.start,
            child: _block(block, counters[block.level.clamp(0, 2)]),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: _Paper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (document.title.isNotEmpty && document.blocks.isEmpty)
              Text(
                document.title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: _heading,
                ),
              ),
            if (document.blocks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  L.of(context).assistantPreviewEmptyDocument,
                  style: const TextStyle(color: _inkSoft),
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _block(DocBlock block, int number) {
    const body = TextStyle(color: _ink, fontSize: 14, height: 1.45);
    switch (block.type) {
      case DocBlockType.heading:
        final size = switch (block.level) {
          1 => 22.0,
          2 => 18.0,
          _ => 15.5,
        };
        return Text.rich(
          _inlineSpan(
            block.text,
            TextStyle(
              color: block.level >= 3 ? const Color(0xff2e4b73) : _heading,
              fontSize: size,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        );
      case DocBlockType.paragraph:
        return Text.rich(_inlineSpan(block.text, body));
      case DocBlockType.quote:
        return Container(
          padding: const EdgeInsetsDirectional.only(start: 14),
          decoration: const BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: _rule, width: 3),
            ),
          ),
          child: Text.rich(
            _inlineSpan(
              block.text,
              body.copyWith(fontStyle: FontStyle.italic, color: _inkSoft),
            ),
          ),
        );
      case DocBlockType.bullet:
      case DocBlockType.numbered:
        final marker = block.type == DocBlockType.bullet
            ? const ['•', '◦', '▪'][block.level.clamp(0, 2)]
            : switch (block.level) {
                0 => '$number.',
                1 => '${String.fromCharCode(96 + number.clamp(1, 26))}.',
                _ => '${_roman(number)}.',
              };
        return Padding(
          padding: EdgeInsetsDirectional.only(start: 18.0 + 22 * block.level),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 24, child: Text(marker, style: body)),
              Expanded(child: Text.rich(_inlineSpan(block.text, body))),
            ],
          ),
        );
      case DocBlockType.pageBreak:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(color: _rule, thickness: 1, height: 1),
        );
      case DocBlockType.table:
        final columns = block.rows.fold(1, (m, r) => math.max(m, r.length));
        return Table(
          border: TableBorder.all(color: _rule, width: 1),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            for (final (r, row) in block.rows.indexed)
              TableRow(
                decoration: r == 0
                    ? const BoxDecoration(color: _tableHead)
                    : null,
                children: [
                  for (var c = 0; c < columns; c++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 5,
                      ),
                      child: Text.rich(
                        _inlineSpan(
                          c < row.length ? row[c] : '',
                          body.copyWith(
                            fontSize: 13,
                            fontWeight: r == 0 ? FontWeight.w700 : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        );
    }
  }

  static String _roman(int n) {
    const values = [10, 9, 5, 4, 1];
    const glyphs = ['x', 'ix', 'v', 'iv', 'i'];
    var rest = n.clamp(1, 39);
    final out = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      while (rest >= values[i]) {
        out.write(glyphs[i]);
        rest -= values[i];
      }
    }
    return out.toString();
  }
}

// ----------------------------------------------------------- slides

class _SlidesView extends StatefulWidget {
  const _SlidesView({
    required this.document,
    required this.focus,
    required this.revision,
  });
  final OfficeDocument document;
  final OfficeFocus? focus;
  final int revision;

  @override
  State<_SlidesView> createState() => _SlidesViewState();
}

class _SlidesViewState extends State<_SlidesView> with _FollowsFocus {
  @override
  Widget build(BuildContext context) {
    follow(widget.revision, widget.focus);
    final luma = context.luma;
    final slides = widget.document.slides;
    final focus = widget.focus;
    if (slides.isEmpty) {
      return Center(
        child: Text(
          L.of(context).assistantPreviewEmptyDocument,
          style: TextStyle(color: luma.textSecondary),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 18, 18, 24),
      child: Column(
        children: [
          for (final (i, slide) in slides.indexed)
            Padding(
              key: keyFor(i),
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: luma.textSecondary, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: _FocusFrame(
                      focused: focus != null && focus.covers(i),
                      activity: focus?.activity,
                      showTag: focus != null && i == focus.start,
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: FittedBox(
                            child: SizedBox(
                              width: 960,
                              height: 540,
                              child: _SlideCanvas(
                                slide: slide,
                                cover: i == 0 && slide.bullets.isEmpty,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A slide drawn on a 960×540 canvas with the same geometry the exporter
/// writes, so the preview matches PowerPoint.
class _SlideCanvas extends StatelessWidget {
  const _SlideCanvas({required this.slide, required this.cover});
  final OfficeSlide slide;
  final bool cover;

  @override
  Widget build(BuildContext context) {
    if (cover) {
      return ColoredBox(
        color: _heading,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 66),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 5),
              Text.rich(
                _inlineSpan(
                  slide.title,
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text.rich(
                _inlineSpan(
                  slide.subtitle,
                  const TextStyle(color: Color(0xffdbeafe), fontSize: 22),
                ),
              ),
              const Spacer(flex: 4),
            ],
          ),
        ),
      );
    }
    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(54, 36, 54, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 72,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text.rich(
                  _inlineSpan(
                    slide.title,
                    const TextStyle(
                      color: _heading,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(width: 108, height: 3, color: const Color(0xff2563eb)),
            const SizedBox(height: 14),
            Expanded(
              child: ClipRect(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (slide.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text.rich(
                          _inlineSpan(
                            slide.subtitle,
                            const TextStyle(color: _inkSoft, fontSize: 20),
                          ),
                        ),
                      ),
                    for (final bullet in slide.bullets)
                      Padding(
                        padding: EdgeInsets.only(
                          left: 27.0 * bullet.level,
                          top: 9,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text(
                                bullet.level == 0 ? '•' : '–',
                                style: const TextStyle(
                                  color: Color(0xff2563eb),
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text.rich(
                                _inlineSpan(
                                  bullet.text,
                                  TextStyle(
                                    color: _ink,
                                    fontSize: bullet.level == 0 ? 20 : 17,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ sheet

class _SheetView extends StatefulWidget {
  const _SheetView({
    required this.document,
    required this.focus,
    required this.revision,
  });
  final OfficeDocument document;
  final OfficeFocus? focus;
  final int revision;

  @override
  State<_SheetView> createState() => _SheetViewState();
}

class _SheetViewState extends State<_SheetView> {
  static const _rowHeight = 26.0;
  static const _rowHeaderWidth = 44.0;
  int _selected = 0;
  int _followedRevision = -1;
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  List<double> _widths(OfficeSheet sheet, int columns) => [
    for (var c = 0; c < columns; c++)
      () {
        var widest = 0;
        for (final row in sheet.rows.take(400)) {
          if (c < row.length) {
            widest = math.max(widest, displayCellValue(sheet, row[c]).length);
          }
        }
        return (widest * 7.4 + 18).clamp(72.0, 300.0);
      }(),
  ];

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final sheets = widget.document.sheets;
    final focus = widget.focus;
    if (sheets.isEmpty) {
      return Center(
        child: Text(
          L.of(context).assistantPreviewEmptyDocument,
          style: TextStyle(color: luma.textSecondary),
        ),
      );
    }
    if (focus != null &&
        focus.start >= 0 &&
        widget.revision != _followedRevision) {
      _selected = focus.start;
    }
    _selected = _selected.clamp(0, sheets.length - 1);
    final sheet = sheets[_selected];
    final columns = math.max(sheet.columnCount + 2, 8);
    final rows = math.max(sheet.rows.length + 6, 30);
    final widths = _widths(sheet, columns);
    final header = sheetHasHeaderRow(sheet);
    final showFocus = focus != null && focus.start == _selected;

    if (showFocus && widget.revision != _followedRevision) {
      _followedRevision = widget.revision;
      final cell = focus.cellStart;
      if (cell != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final reduce = MediaQuery.of(context).disableAnimations;
          void go(ScrollController controller, double offset) {
            if (!controller.hasClients) return;
            final target = offset.clamp(
              0.0,
              controller.position.maxScrollExtent,
            );
            final visible = controller.position.viewportDimension;
            if (target >= controller.offset &&
                target <= controller.offset + visible - 60) {
              return;
            }
            if (reduce) {
              controller.jumpTo(target);
            } else {
              controller.animateTo(
                target,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            }
          }

          go(_vertical, math.max(0, cell.$1 - 3) * _rowHeight);
          go(
            _horizontal,
            widths.take(cell.$2).fold<double>(0, (a, b) => a + b) - 40,
          );
        });
      }
    } else if (!showFocus) {
      _followedRevision = widget.revision;
    }

    final gridLine = luma.border;
    final accent = focus?.activity == OfficeActivity.reading
        ? const Color(0xff0ea5e9)
        : luma.accent;
    Widget headerCell(String text, double width) => Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(
          right: BorderSide(color: gridLine),
          bottom: BorderSide(color: gridLine),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: luma.textSecondary),
      ),
    );

    final totalWidth =
        _rowHeaderWidth + widths.fold<double>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Scrollbar(
            controller: _horizontal,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  children: [
                    Row(
                      children: [
                        headerCell('', _rowHeaderWidth),
                        for (var c = 0; c < columns; c++)
                          headerCell(columnName(c), widths[c]),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _vertical,
                        itemExtent: _rowHeight,
                        itemCount: rows,
                        itemBuilder: (context, r) => Row(
                          children: [
                            headerCell('${r + 1}', _rowHeaderWidth),
                            for (var c = 0; c < columns; c++)
                              _cell(
                                sheet,
                                r,
                                c,
                                widths[c],
                                bold: header && r == 0 && c < sheet.columnCount,
                                focused: showFocus && focus.coversCell(r, c),
                                accent: accent,
                                gridLine: gridLine,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (sheets.length > 1 || sheets.first.name != 'Sheet1')
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: luma.surface,
              border: Border(top: BorderSide(color: luma.border)),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (i, s) in sheets.indexed)
                  InkWell(
                    onTap: () => setState(() => _selected = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == _selected ? luma.background : null,
                        border: Border(
                          top: BorderSide(
                            color: i == _selected
                                ? luma.accent
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: i == _selected
                              ? luma.textPrimary
                              : luma.textSecondary,
                          fontWeight: i == _selected ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(
    OfficeSheet sheet,
    int r,
    int c,
    double width, {
    required bool bold,
    required bool focused,
    required Color accent,
    required Color gridLine,
  }) {
    final raw = sheet.cell(r, c);
    final value = displayCellValue(sheet, raw);
    final numeric = parseSheetNumber(value) != null;
    return Container(
      width: width,
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: focused
            ? accent.withValues(alpha: 0.14)
            : bold
            ? context.luma.accentSubtle
            : null,
        border: focused
            ? Border.all(color: accent, width: 1.2)
            : Border(
                right: BorderSide(color: gridLine),
                bottom: BorderSide(color: gridLine),
              ),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          color: context.luma.textPrimary,
          fontWeight: bold ? FontWeight.w600 : null,
        ),
      ),
    );
  }
}

// ------------------------------------------------------ plain files

class _PdfView extends StatefulWidget {
  const _PdfView({required this.path});
  final String path;
  @override
  State<_PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<_PdfView> {
  late final Future<List<String>> _pages = _extract();

  Future<List<String>> _extract() async {
    final bytes = await File(widget.path).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      return [
        for (var i = 0; i < document.pages.count; i++)
          extractor.extractText(startPageIndex: i, endPageIndex: i),
      ];
    } finally {
      document.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _pages,
    builder: (context, snap) {
      final t = L.of(context);
      if (snap.hasError) {
        return Center(child: Text(t.assistantPreviewUnsupported));
      }
      final pages = snap.data;
      if (pages == null) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
      }
      if (pages.every((p) => p.trim().isEmpty)) {
        return Center(child: Text(t.assistantPreviewNoPdfText));
      }
      return ListView.builder(
        itemCount: pages.length,
        itemBuilder: (context, i) => _Paper(
          child: SelectableText(
            pages[i].trimRight(),
            style: const TextStyle(color: _ink, fontSize: 13.5, height: 1.5),
          ),
        ),
      );
    },
  );
}

class _TextView extends StatefulWidget {
  const _TextView({required this.path, required this.markdown});
  final String path;
  final bool markdown;
  @override
  State<_TextView> createState() => _TextViewState();
}

class _TextViewState extends State<_TextView> {
  late final Future<String> _text = File(widget.path).readAsString();

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _text,
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(child: Text(L.of(context).assistantPreviewUnsupported));
      }
      final text = snap.data;
      if (text == null) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: widget.markdown
            ? ChatMarkdown(source: text)
            : SelectableText(
                text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.45,
                  color: context.luma.textPrimary,
                ),
              ),
      );
    },
  );
}
