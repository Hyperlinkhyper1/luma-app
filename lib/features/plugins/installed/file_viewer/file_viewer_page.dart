import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import '../../../converter/converter_widgets.dart';
import 'document_extractors.dart';

/// What the viewer knows how to render, detected from the file extension.
enum _FileKind { image, svg, pdf, docx, xlsx, text, unsupported }

const _imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
const _textExts = {
  'txt', 'md', 'json', 'xml', 'yaml', 'yml', 'csv', 'tsv', 'log', 'ini',
  'toml', 'properties', 'dart', 'js', 'ts', 'html', 'css', 'py', 'java',
  'c', 'cpp', 'h', 'cs', 'sh', 'bat', 'ps1', 'sql', 'gradle', 'env',
};

_FileKind _kindFor(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  if (_imageExts.contains(ext)) return _FileKind.image;
  if (ext == 'svg') return _FileKind.svg;
  if (ext == 'pdf') return _FileKind.pdf;
  if (ext == 'docx') return _FileKind.docx;
  if (ext == 'xlsx') return _FileKind.xlsx;
  if (_textExts.contains(ext)) return _FileKind.text;
  return _FileKind.unsupported;
}

/// The File Viewer plugin: open a document and read it right inside luma —
/// PDFs (per-page text), Word documents, Excel workbooks, images, SVGs, and
/// any plain-text or code file. Parsing runs in a background isolate.
class FileViewerPage extends StatefulWidget {
  const FileViewerPage({super.key});

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  Uint8List? _bytes;
  String? _name;
  String? _path;
  int _size = 0;
  _FileKind _kind = _FileKind.unsupported;

  bool _loading = false;
  String? _error;

  // Parsed content — only the field matching [_kind] is populated.
  // PDFs render natively (WebView2 on Windows) from a local file path;
  // extracted page text is the web-platform fallback only.
  String? _pdfPath;
  List<String>? _pdfPages;
  int _pdfPage = 0;
  List<DocxParagraph>? _docxParagraphs;
  List<List<String>>? _xlsxGrid;
  String? _textContent;

  // Guards against a stale parse landing after the user picked another file.
  int _request = 0;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _error = 'Could not read the selected file.');
      return;
    }

    final kind = _kindFor(file.name);
    final request = ++_request;
    setState(() {
      _bytes = bytes;
      _name = file.name;
      _path = kIsWeb ? null : file.path;
      _size = file.size;
      _kind = kind;
      _error = null;
      _pdfPath = null;
      _pdfPages = null;
      _pdfPage = 0;
      _docxParagraphs = null;
      _xlsxGrid = null;
      _textContent = null;
      _loading = kind == _FileKind.pdf ||
          kind == _FileKind.docx ||
          kind == _FileKind.xlsx ||
          kind == _FileKind.text;
    });

    try {
      switch (kind) {
        case _FileKind.pdf:
          if (!kIsWeb) {
            // Render the actual PDF natively; make sure it exists on disk.
            final path = _path ?? await _writeTempFile(file.name, bytes);
            if (!mounted || request != _request) return;
            setState(() {
              _pdfPath = path;
              _loading = false;
            });
          } else {
            final pages = await compute(extractPdfPages, bytes);
            if (!mounted || request != _request) return;
            setState(() {
              _pdfPages = pages;
              _loading = false;
            });
          }
        case _FileKind.docx:
          final paragraphs = await compute(extractDocxParagraphs, bytes);
          if (!mounted || request != _request) return;
          setState(() {
            _docxParagraphs = paragraphs;
            _loading = false;
          });
        case _FileKind.xlsx:
          final grid = await compute(extractXlsxGrid, bytes);
          if (!mounted || request != _request) return;
          setState(() {
            _xlsxGrid = grid;
            _loading = false;
          });
        case _FileKind.text:
          final text = utf8.decode(bytes, allowMalformed: true);
          if (!mounted || request != _request) return;
          setState(() {
            _textContent = text;
            _loading = false;
          });
        case _FileKind.image:
        case _FileKind.svg:
        case _FileKind.unsupported:
          break;
      }
    } on FormatException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = 'Could not open this file: $e';
      });
    }
  }

  /// Writes picked bytes to a temp file so file-based renderers (the PDF
  /// WebView) can load them when the picker didn't supply a path.
  static Future<String> _writeTempFile(String name, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}luma_file_viewer'
        '${Platform.pathSeparator}$name');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _openExternally() async {
    final path = _path;
    if (path == null) return;
    final result = await OpenFile.open(path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      setState(() => _error = 'Could not open externally: ${result.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_bytes == null)
                ConverterDropZone(
                  onTap: _pickFile,
                  icon: Icons.file_open_outlined,
                  title: 'Click to choose a file',
                  subtitle: 'PDF · DOCX · XLSX · images · SVG · text & code',
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ConverterFileCard(
                        name: _name!,
                        icon: _iconFor(_kind),
                        badge: FormatChip(label: _extensionLabel(_name!)),
                        meta: formatBytes(_size),
                        onChange: _pickFile,
                      ),
                    ),
                    if (_path != null) ...[
                      const SizedBox(width: 12),
                      LumaGhostButton(
                        label: 'Open externally',
                        icon: Icons.open_in_new_rounded,
                        onTap: _openExternally,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  ConverterBanner(
                    icon: Icons.error_outline_rounded,
                    color: luma.danger,
                    message: _error!,
                  )
                else if (_loading)
                  const LumaCard(
                    child: SizedBox(
                      height: 220,
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.6),
                        ),
                      ),
                    ),
                  )
                else
                  _buildViewer(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewer() {
    switch (_kind) {
      case _FileKind.image:
        return _ImageViewer(bytes: _bytes!);
      case _FileKind.svg:
        return _SvgViewer(bytes: _bytes!);
      case _FileKind.pdf:
        final path = _pdfPath;
        if (path != null) return _PdfWebViewer(path: path);
        final pages = _pdfPages;
        if (pages == null) return const SizedBox.shrink();
        return _PdfViewer(
          pages: pages,
          page: _pdfPage,
          onPageChanged: (p) => setState(() => _pdfPage = p),
        );
      case _FileKind.docx:
        final paragraphs = _docxParagraphs;
        if (paragraphs == null) return const SizedBox.shrink();
        return _DocxViewer(paragraphs: paragraphs);
      case _FileKind.xlsx:
        final grid = _xlsxGrid;
        if (grid == null) return const SizedBox.shrink();
        return _XlsxViewer(grid: grid);
      case _FileKind.text:
        final text = _textContent;
        if (text == null) return const SizedBox.shrink();
        return _TextViewer(text: text);
      case _FileKind.unsupported:
        return LumaCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: LumaEmptyState(
              icon: Icons.visibility_off_outlined,
              title: 'No preview for this file type',
              subtitle: _path != null
                  ? 'Use "Open externally" to view it in its default app.'
                  : 'This file type can\'t be previewed here.',
            ),
          ),
        );
    }
  }

  static IconData _iconFor(_FileKind kind) => switch (kind) {
        _FileKind.image => Icons.image_outlined,
        _FileKind.svg => Icons.polyline_outlined,
        _FileKind.pdf => Icons.picture_as_pdf_outlined,
        _FileKind.docx => Icons.article_outlined,
        _FileKind.xlsx => Icons.grid_on_outlined,
        _FileKind.text => Icons.code_rounded,
        _FileKind.unsupported => Icons.insert_drive_file_outlined,
      };

  static String _extensionLabel(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? 'FILE' : name.substring(dot + 1).toUpperCase();
  }
}

// ---- Viewers ------------------------------------------------------------------

/// Zoomable/pannable raster image on a checkerboard so transparency shows.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 480,
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _CheckerboardPainter()),
            InteractiveViewer(
              maxScale: 8,
              child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SvgViewer extends StatelessWidget {
  const _SvgViewer({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 480,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
      ),
      child: InteractiveViewer(
        maxScale: 8,
        child: Center(child: SvgPicture.memory(bytes)),
      ),
    );
  }
}

/// The real PDF rendered by the platform webview (WebView2 on Windows ships
/// a full PDF viewer: proper layout, images, zoom, search, page thumbnails).
class _PdfWebViewer extends StatefulWidget {
  const _PdfWebViewer({required this.path});
  final String path;

  @override
  State<_PdfWebViewer> createState() => _PdfWebViewerState();
}

class _PdfWebViewerState extends State<_PdfWebViewer> {
  InAppWebViewController? _controller;
  bool _loading = true;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // The page scrolls vertically, so the viewer gets a generous fixed
    // height; the PDF scrolls inside it.
    final height =
        (MediaQuery.sizeOf(context).height - 240).clamp(420.0, 1200.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            InAppWebView(
              key: ValueKey(widget.path),
              initialUrlRequest: URLRequest(
                url: WebUri(Uri.file(widget.path).toString()),
              ),
              initialSettings: InAppWebViewSettings(
                transparentBackground: true,
                allowFileAccess: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
              ),
              onWebViewCreated: (controller) => _controller = controller,
              onLoadStop: (controller, url) {
                if (mounted) setState(() => _loading = false);
              },
            ),
            if (_loading)
              Container(
                color: luma.surface,
                child: const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Per-page extracted PDF text with previous/next navigation — the fallback
/// for platforms without an embeddable native PDF renderer (web).
class _PdfViewer extends StatelessWidget {
  const _PdfViewer({
    required this.pages,
    required this.page,
    required this.onPageChanged,
  });

  final List<String> pages;
  final int page;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final text = pages.isEmpty ? '' : pages[page];
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PagerButton(
                icon: Icons.chevron_left_rounded,
                enabled: page > 0,
                onTap: () => onPageChanged(page - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Page ${page + 1} of ${pages.length}',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _PagerButton(
                icon: Icons.chevron_right_rounded,
                enabled: page < pages.length - 1,
                onTap: () => onPageChanged(page + 1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (text.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: LumaEmptyState(
                icon: Icons.image_not_supported_outlined,
                title: 'No text on this page',
                subtitle:
                    'This page has no extractable text — it may be a scan '
                    'or an image.',
              ),
            )
          else
            SelectableText(
              text,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: luma.surfaceHover,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: luma.border),
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? luma.textPrimary : luma.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Word document rendered as styled paragraphs: headings, bold, bullets.
class _DocxViewer extends StatelessWidget {
  const _DocxViewer({required this.paragraphs});
  final List<DocxParagraph> paragraphs;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (paragraphs
        .every((p) => p.text.trim().isEmpty && p.images.isEmpty)) {
      return LumaCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: LumaEmptyState(
            icon: Icons.article_outlined,
            title: 'This document has no readable text',
          ),
        ),
      );
    }
    return LumaCard(
      padding: const EdgeInsets.all(28),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in paragraphs) _paragraph(p, luma),
          ],
        ),
      ),
    );
  }

  Widget _paragraph(DocxParagraph p, LumaPalette luma) {
    if (p.text.trim().isEmpty && p.images.isEmpty) {
      return const SizedBox(height: 12);
    }

    final isHeading = p.headingLevel > 0;
    final style = TextStyle(
      color: luma.textPrimary,
      fontSize: isHeading ? (24 - p.headingLevel * 2).clamp(15, 22).toDouble() : 14,
      height: 1.6,
      fontWeight: isHeading || p.bold ? FontWeight.w700 : FontWeight.w400,
    );

    Widget? text =
        p.text.trim().isEmpty ? null : Text(p.text, style: style);
    if (text != null && p.bullet) {
      text = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10, left: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: luma.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: text),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: isHeading ? 14 : 0, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?text,
          for (final image in p.images)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 480),
                  child: Image.memory(image, fit: BoxFit.contain),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// First worksheet of an xlsx as a scrollable grid, header row emphasized.
class _XlsxViewer extends StatelessWidget {
  const _XlsxViewer({required this.grid});
  final List<List<String>> grid;

  static const _maxRows = 300;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (grid.isEmpty) {
      return LumaCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: LumaEmptyState(
            icon: Icons.grid_on_outlined,
            title: 'This worksheet is empty',
          ),
        ),
      );
    }

    final rows = grid.length > _maxRows ? grid.sublist(0, _maxRows) : grid;
    return LumaCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var r = 0; r < rows.length; r++)
                    Container(
                      decoration: BoxDecoration(
                        color: r == 0 ? luma.surfaceHover : null,
                        border: Border(
                          bottom: BorderSide(
                            color: luma.border.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          for (final cell in rows[r])
                            Container(
                              width: 140,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Text(
                                cell,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: r == 0
                                      ? luma.textPrimary
                                      : luma.textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: r == 0
                                      ? FontWeight.w700
                                      : FontWeight.w400,
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
          if (grid.length > _maxRows) ...[
            const SizedBox(height: 10),
            Text(
              'Showing the first $_maxRows of ${grid.length} rows.',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Plain text / code in a monospace block.
class _TextViewer extends StatelessWidget {
  const _TextViewer({required this.text});
  final String text;

  static const _maxChars = 500 * 1024;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final truncated = text.length > _maxChars;
    final shown = truncated ? text.substring(0, _maxChars) : text;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            shown,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13,
              height: 1.55,
              fontFamily: 'monospace',
            ),
          ),
          if (truncated) ...[
            const SizedBox(height: 12),
            Text(
              'Large file — showing the first 500 KB.',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 16.0;
    final paint = Paint();
    for (var y = 0.0; y < size.height; y += cellSize) {
      for (var x = 0.0; x < size.width; x += cellSize) {
        final row = (y / cellSize).floor();
        final col = (x / cellSize).floor();
        paint.color = (row + col).isEven
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFE0E0E0);
        canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
