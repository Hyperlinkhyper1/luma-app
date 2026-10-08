import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'data/whiteboard_database.dart';
import 'ui/whiteboard_canvas.dart';
import 'whiteboard_scope.dart';

/// The plugin's entry point: a shelf of boards that opens into the canvas.
class WhiteboardPage extends StatefulWidget {
  const WhiteboardPage({super.key});

  @override
  State<WhiteboardPage> createState() => _WhiteboardPageState();
}

class _WhiteboardPageState extends State<WhiteboardPage> {
  int? _openBoardId;

  @override
  Widget build(BuildContext context) {
    final repository = WhiteboardScope.of(context);
    final openId = _openBoardId;
    if (openId == null) {
      return _BoardShelf(onOpen: (id) => setState(() => _openBoardId = id));
    }
    return StreamData<Board?>(
      stream: repository.watchBoard(openId),
      builder: (context, board) {
        if (board == null) {
          // Deleted from another device while it was open.
          return _BoardShelf(onOpen: (id) => setState(() => _openBoardId = id));
        }
        return WhiteboardCanvas(
          key: ValueKey(board.id),
          board: board,
          repository: repository,
          onClose: () => setState(() => _openBoardId = null),
        );
      },
    );
  }
}

class _BoardShelf extends StatefulWidget {
  const _BoardShelf({required this.onOpen});

  final ValueChanged<int> onOpen;

  @override
  State<_BoardShelf> createState() => _BoardShelfState();
}

class _BoardShelfState extends State<_BoardShelf> {
  final _title = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final id = await WhiteboardScope.of(context).createBoard(title);
      _title.clear();
      if (mounted) widget.onOpen(id);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _rename(Board board) async {
    final t = L.of(context);
    final controller = TextEditingController(text: board.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.whiteboardRenameTooltip),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: t.commonName),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(t.commonRename),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
    if (title == null || title.trim().isEmpty || !mounted) return;
    await WhiteboardScope.of(context).renameBoard(board.id, title.trim());
  }

  Future<void> _confirmDelete(Board board, int count) async {
    final t = L.of(context);
    final danger = context.luma.danger;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.whiteboardDeleteBoardTitle(board.title)),
        content: Text(t.whiteboardDeleteBoardContent(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.commonDelete),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false) || !mounted) return;
    await WhiteboardScope.of(context).deleteBoard(board.id);
  }

  @override
  Widget build(BuildContext context) {
    final repository = WhiteboardScope.of(context);
    final t = L.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 760;

    return StreamData<List<Board>>(
      stream: repository.watchBoards(),
      builder: (context, boards) {
        return StreamData<Map<int, int>>(
          stream: repository.watchElementCounts(),
          builder: (context, counts) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                narrow ? 12 : 24,
                8,
                narrow ? 12 : 24,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _title,
                          decoration: InputDecoration(
                            hintText: t.whiteboardNameHint,
                            isDense: true,
                            prefixIcon: Icon(Icons.draw_rounded, size: 18),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _create(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      LumaPrimaryButton(
                        label: t.commonCreate,
                        icon: Icons.add_rounded,
                        loading: _creating,
                        onTap: _create,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: boards.isEmpty
                        ? LumaEmptyState(
                            icon: Icons.draw_rounded,
                            title: t.whiteboardEmptyTitle,
                            subtitle: t.whiteboardEmptySubtitle,
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 300,
                              mainAxisExtent: 108,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: boards.length,
                            itemBuilder: (context, index) {
                              final board = boards[index];
                              return _BoardCard(
                                board: board,
                                count: counts[board.id] ?? 0,
                                onOpen: () => widget.onOpen(board.id),
                                onRename: () => _rename(board),
                                onDelete: () => _confirmDelete(
                                  board,
                                  counts[board.id] ?? 0,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.board,
    required this.count,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final Board board;
  final int count;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return LumaCard(
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      board.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: t.whiteboardRenameTooltip,
                    iconSize: 18,
                    icon: Icon(Icons.edit_outlined, color: luma.textMuted),
                    onPressed: onRename,
                  ),
                  IconButton(
                    tooltip: t.whiteboardDeleteBoardTooltip,
                    iconSize: 18,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: luma.textMuted,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.draw_rounded, size: 13, color: luma.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    t.whiteboardItemCount(count),
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
                  const Spacer(),
                  Text(
                    _relative(t, board.updatedAt),
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _relative(L t, DateTime when) {
    final difference = DateTime.now().difference(when);
    if (difference.inMinutes < 1) return t.commonJustNow;
    if (difference.inHours < 1) return t.commonMinutesAgo(difference.inMinutes);
    if (difference.inDays < 1) return t.commonHoursAgo(difference.inHours);
    if (difference.inDays < 30) return t.commonDaysAgo(difference.inDays);
    return '${when.year}-${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')}';
  }
}
