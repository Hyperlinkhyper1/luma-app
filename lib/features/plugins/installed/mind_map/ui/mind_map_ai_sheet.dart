import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../settings/settings_scope.dart';
import '../../../../../theme/luma_theme.dart';
import '../../../../chat/ai_key_store.dart';
import '../../../../chat/providers/ai_client.dart';
import '../../../../chat/providers/ai_providers.dart';
import '../data/mind_map_database.dart';
import '../io/mind_map_outline.dart';
import '../mind_map_repository.dart';

/// Asks the configured AI provider for child ideas under one node.
///
/// Nothing is written until the user ticks what they want and confirms, so a
/// bad suggestion costs a glance rather than a clean-up. The request goes
/// straight to the provider with the user's own key — the same single-turn
/// [AiClient.chat] call the Minecraft launcher's crash analyser uses — so no
/// luma server is involved.
class MindMapAiSheet extends StatefulWidget {
  const MindMapAiSheet({
    super.key,
    required this.repository,
    required this.mapTitle,
    required this.mapId,
    required this.node,
    required this.path,
    required this.existingChildren,
  });

  final MindMapRepository repository;
  final String mapTitle;
  final int mapId;
  final MindMapNode node;

  /// Root-to-node labels, so the model knows where in the map it is.
  final List<String> path;
  final List<String> existingChildren;

  /// Returns how many nodes were added, or null if nothing was.
  static Future<int?> show(
    BuildContext context, {
    required MindMapRepository repository,
    required String mapTitle,
    required int mapId,
    required MindMapNode node,
    required List<String> path,
    required List<String> existingChildren,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: MindMapAiSheet(
            repository: repository,
            mapTitle: mapTitle,
            mapId: mapId,
            node: node,
            path: path,
            existingChildren: existingChildren,
          ),
        ),
      ),
    );
  }

  @override
  State<MindMapAiSheet> createState() => _MindMapAiSheetState();
}

class _MindMapAiSheetState extends State<MindMapAiSheet> {
  static const _maxSuggestions = 10;

  bool _loading = true;
  bool _adding = false;
  String? _error;
  bool _errorIsRetryable = true;
  List<String> _suggestions = const [];
  final _chosen = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _request());
  }

  Future<void> _request() async {
    setState(() {
      _loading = true;
      _error = null;
      _suggestions = const [];
      _chosen.clear();
    });

    final settings = SettingsScope.of(context);
    final provider = aiProviderById(settings.aiProviderId);

    if (!settings.canSendAiMessage) {
      _fail("You've used today's AI allowance — more tomorrow.", retryable: false);
      return;
    }

    final store = await AiKeyStore.load();
    final apiKey = await store.readKey(provider.id.name);
    if (apiKey == null || apiKey.isEmpty) {
      _fail(
        'No API key saved for ${provider.displayName}. Add one under '
        'Settings → AI Assistant to use this.',
        retryable: false,
      );
      return;
    }

    try {
      final result = await provider.client.chat(
        apiKey: apiKey,
        history: [AiTurn(role: 'user', text: _prompt())],
        systemPrompt:
            'You extend mind maps. Given where a node sits in the map, reply with '
            'ideas that belong directly beneath it — one per line, nothing else. '
            'No numbering, no bullets, no commentary, no headings. Each line is a '
            'short label of at most six words. Give between three and eight lines.',
        tools: const [],
        executeTool: (_, _) async => const {},
        metadataFor: (_, _) => null,
      );
      settings.recordAiCall();
      final parsed = _parse(result.text);
      if (!mounted) return;
      if (parsed.isEmpty) {
        _fail('The model did not suggest anything usable. Try again.');
        return;
      }
      setState(() {
        _loading = false;
        _suggestions = parsed;
        _chosen.addAll(parsed);
      });
    } on AiError catch (error) {
      _fail(error.message);
    } catch (error) {
      _fail('$error');
    }
  }

  void _fail(String message, {bool retryable = true}) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
      _errorIsRetryable = retryable;
    });
  }

  String _prompt() {
    final buffer = StringBuffer()
      ..writeln('Mind map: ${widget.mapTitle}')
      ..writeln('Path to the node: ${widget.path.join(' > ')}')
      ..writeln('Node to expand: ${widget.node.label}');
    if (widget.node.note != null && widget.node.note!.trim().isNotEmpty) {
      buffer.writeln('Its note: ${widget.node.note!.trim()}');
    }
    if (widget.existingChildren.isNotEmpty) {
      buffer
        ..writeln('It already has these children, so do not repeat them:')
        ..writeln(widget.existingChildren.map((c) => '- $c').join('\n'));
    }
    buffer.writeln('List the ideas that should sit directly under it.');
    return buffer.toString();
  }

  /// The model is asked for bare lines, but it is not obliged to comply, so
  /// bullets and numbering are stripped and anything sentence-length is
  /// dropped rather than turned into an unreadably wide node.
  List<String> _parse(String text) {
    final seen = <String>{
      for (final existing in widget.existingChildren) existing.trim().toLowerCase(),
    };
    final result = <String>[];
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      var line = raw.trim();
      if (line.isEmpty) continue;
      line = line.replaceFirst(RegExp(r'^([-*+•]|\d+[.)])\s+'), '');
      line = line.replaceAll(RegExp(r'^\*\*|\*\*$'), '').trim();
      if (line.isEmpty || line.length > 80) continue;
      if (line.endsWith(':')) continue;
      if (!seen.add(line.toLowerCase())) continue;
      result.add(line);
      if (result.length >= _maxSuggestions) break;
    }
    return result;
  }

  Future<void> _add() async {
    if (_chosen.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      final added = await widget.repository.insertOutline(
        mapId: widget.mapId,
        parentId: widget.node.id,
        roots: [
          for (final suggestion in _suggestions)
            if (_chosen.contains(suggestion)) OutlineNode(label: suggestion),
        ],
      );
      if (mounted) Navigator.pop(context, added);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Expand "${widget.node.label}"',
                  overflow: TextOverflow.ellipsis,
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
          _body(luma),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_suggestions.isNotEmpty)
                Expanded(
                  child: Text(
                    '${_chosen.length} of ${_suggestions.length} selected',
                    style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
                  ),
                ),
              if (!_loading && (_error == null || _errorIsRetryable))
                LumaGhostButton(
                  label: _suggestions.isEmpty ? 'Try again' : 'Suggest more',
                  icon: Icons.refresh_rounded,
                  onTap: _request,
                ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(width: 10),
                LumaPrimaryButton(
                  label: 'Add ${_chosen.length}',
                  icon: Icons.add_rounded,
                  loading: _adding,
                  onTap: _chosen.isEmpty || _adding ? null : _add,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(LumaPalette luma) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    if (_error != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: luma.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: luma.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final suggestion in _suggestions)
              CheckboxListTile(
                value: _chosen.contains(suggestion),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    _chosen.add(suggestion);
                  } else {
                    _chosen.remove(suggestion);
                  }
                }),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  suggestion,
                  style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
