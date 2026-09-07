import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/mind_map_database.dart';
import '../mind_map_repository.dart';
import 'mind_map_style.dart';

/// The detail editor for one node: its full label, a longer note, a link, and
/// the branch colour.
///
/// Presented as a dialog on desktop and a bottom sheet on a phone, so the
/// controls stay within thumb reach on a small screen instead of being
/// stranded in the middle of the canvas.
class MindMapInspector extends StatefulWidget {
  const MindMapInspector({
    super.key,
    required this.node,
    required this.repository,
    required this.inheritedColor,
  });

  final MindMapNode node;
  final MindMapRepository repository;

  /// What the node paints with when it has no colour of its own — shown as
  /// the "Inherit" swatch so the choice is visible rather than implied.
  final Color inheritedColor;

  static Future<void> show(
    BuildContext context, {
    required MindMapNode node,
    required MindMapRepository repository,
    required Color inheritedColor,
  }) {
    final panel = MindMapInspector(
      node: node,
      repository: repository,
      inheritedColor: inheritedColor,
    );
    final narrow = MediaQuery.sizeOf(context).width < 700;
    if (narrow) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: panel,
        ),
      );
    }
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: panel,
        ),
      ),
    );
  }

  @override
  State<MindMapInspector> createState() => _MindMapInspectorState();
}

class _MindMapInspectorState extends State<MindMapInspector> {
  late final _label = TextEditingController(text: widget.node.label);
  late final _note = TextEditingController(text: widget.node.note ?? '');
  late final _link = TextEditingController(text: widget.node.link ?? '');
  late int? _color = widget.node.color;

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    final note = _note.text.trim();
    final link = _link.text.trim();
    await widget.repository.updateNode(
      widget.node.id,
      label: label.isEmpty ? widget.node.label : label,
      note: note.isEmpty ? null : note,
      link: link.isEmpty ? null : link,
      color: _color,
      clearNote: note.isEmpty,
      clearLink: link.isEmpty,
      clearColor: _color == null,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: luma.border),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Node details',
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
            const SizedBox(height: 12),
            _FieldLabel('Label'),
            TextField(
              controller: _label,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(isDense: true),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Note'),
            TextField(
              controller: _note,
              maxLines: 6,
              minLines: 3,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Anything that does not belong on the canvas',
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Link'),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'https://',
                prefixIcon: Icon(Icons.link_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 18),
            _FieldLabel('Colour'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Swatch(
                  color: widget.inheritedColor,
                  selected: _color == null,
                  inherit: true,
                  onTap: () => setState(() => _color = null),
                ),
                for (final color in MindMapStyle.branchColors)
                  _Swatch(
                    color: color,
                    selected: _color == color.toARGB32(),
                    inherit: false,
                    onTap: () => setState(() => _color = color.toARGB32()),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                LumaGhostButton(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 10),
                LumaPrimaryButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  onTap: _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: context.luma.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.inherit,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final bool inherit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      button: true,
      selected: selected,
      label: inherit ? 'Inherit branch colour' : 'Colour swatch',
      child: Tooltip(
        message: inherit ? 'Inherit from branch' : '',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            // 44x44 keeps the swatch a comfortable touch target even though
            // the coloured dot inside it is smaller.
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? luma.textPrimary : luma.border,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: inherit
                      ? Icon(Icons.auto_awesome_rounded,
                          size: 14, color: luma.onAccent)
                      : selected
                          ? Icon(Icons.check_rounded,
                              size: 16, color: luma.onAccent)
                          : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
