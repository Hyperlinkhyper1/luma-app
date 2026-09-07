import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../io/mind_map_outline.dart';
import '../mind_map_repository.dart';

/// Turns a pasted outline into a whole branch in one go.
///
/// Typing a big map node by node is the slow path; most ideas already exist
/// somewhere as an indented list, so this accepts tabs, spaces, bullets or
/// Markdown headings and shows exactly what it understood before anything is
/// written.
class MindMapImportSheet extends StatefulWidget {
  const MindMapImportSheet({
    super.key,
    required this.repository,
    required this.mapId,
    required this.parentId,
    required this.parentLabel,
  });

  final MindMapRepository repository;
  final int mapId;
  final int? parentId;
  final String? parentLabel;

  /// Returns how many nodes were added, or null if nothing was imported.
  static Future<int?> show(
    BuildContext context, {
    required MindMapRepository repository,
    required int mapId,
    required int? parentId,
    required String? parentLabel,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: MindMapImportSheet(
            repository: repository,
            mapId: mapId,
            parentId: parentId,
            parentLabel: parentLabel,
          ),
        ),
      ),
    );
  }

  @override
  State<MindMapImportSheet> createState() => _MindMapImportSheetState();
}

class _MindMapImportSheetState extends State<MindMapImportSheet> {
  final _controller = TextEditingController();
  List<OutlineNode> _parsed = const [];
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reparse);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reparse() {
    setState(() => _parsed = MindMapOutline.parse(_controller.text));
  }

  int get _total =>
      _parsed.fold<int>(0, (sum, node) => sum + 1 + node.descendantCount);

  Future<void> _import() async {
    if (_parsed.isEmpty || _importing) return;
    setState(() => _importing = true);
    try {
      final added = await widget.repository.insertOutline(
        mapId: widget.mapId,
        parentId: widget.parentId,
        roots: _parsed,
      );
      if (mounted) Navigator.pop(context, added);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final target = widget.parentLabel?.trim();
    return Container(
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: luma.border),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Paste an outline',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            target == null || target.isEmpty
                ? 'Adds new branches at the root of this map.'
                : 'Adds under "$target".',
            style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 10,
            minLines: 6,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              alignLabelWithHint: true,
              hintText: 'Launch plan\n  Research\n    Competitors\n  Design\n  Ship',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Indentation makes children. Tabs or spaces, bullets, numbers and '
            'Markdown headings all work. A "> " line becomes a note.',
            style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.4),
          ),
          if (_parsed.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: luma.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: luma.border),
              ),
              child: SingleChildScrollView(
                child: Text(
                  MindMapOutline.toMarkdown(_parsed).trimRight(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                    color: luma.textSecondary,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_parsed.isNotEmpty)
                Expanded(
                  child: Text(
                    '$_total ${_total == 1 ? 'node' : 'nodes'} will be added',
                    style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
                  ),
                ),
              LumaGhostButton(
                label: 'Cancel',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: 'Add to map',
                icon: Icons.add_rounded,
                loading: _importing,
                onTap: _parsed.isEmpty || _importing ? null : _import,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
