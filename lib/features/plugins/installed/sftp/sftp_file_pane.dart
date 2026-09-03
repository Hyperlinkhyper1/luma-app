import 'package:flutter/material.dart';

import '../../../../theme/luma_theme.dart';
import 'sftp_paths.dart';

/// Which half of the browser a pane (or a drag) belongs to.
enum PaneSide { local, remote }

/// One row in a pane. Both `LocalEntry` and `SftpEntry` are mapped onto this
/// so the two panes are literally the same widget — a file behaves the same
/// on either side, which is the whole point of a two-pane transfer client.
class PaneEntry {
  const PaneEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isLink = false,
    this.size = 0,
    this.modified,
    this.permissions,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final bool isLink;
  final int size;
  final DateTime? modified;

  /// `rwxr-xr-x`, remote side only.
  final String? permissions;
}

/// What travels between the panes during a drag.
class PaneDragPayload {
  const PaneDragPayload({required this.side, required this.entries});

  final PaneSide side;
  final List<PaneEntry> entries;
}

/// One side of the browser: a header with the path and its actions, and the
/// directory listing under it.
///
/// The pane is deliberately dumb — it renders what it is given and reports
/// intent upward. Both the local and the remote side own their own loading,
/// error and selection state in [SftpPage].
class SftpFilePane extends StatelessWidget {
  const SftpFilePane({
    super.key,
    required this.side,
    required this.title,
    required this.path,
    required this.crumbs,
    required this.entries,
    required this.selection,
    required this.loading,
    required this.error,
    required this.canGoUp,
    required this.onUp,
    required this.onRefresh,
    required this.onHome,
    required this.onNewFolder,
    required this.onNavigate,
    required this.onOpen,
    required this.onToggleSelect,
    required this.onContextMenu,
    required this.onDropped,
    this.subtitle,
    this.emptyMessage = 'This folder is empty.',
    this.compact = false,
  });

  final PaneSide side;
  final String title;
  final String? subtitle;
  final String path;
  final List<({String label, String path})> crumbs;
  final List<PaneEntry> entries;

  /// Paths of the currently selected entries.
  final Set<String> selection;

  final bool loading;
  final String? error;
  final bool canGoUp;

  final VoidCallback onUp;
  final VoidCallback onRefresh;
  final VoidCallback onHome;
  final VoidCallback onNewFolder;

  /// Jump straight to a directory (breadcrumb tap).
  final ValueChanged<String> onNavigate;

  /// Open an entry: descend into a folder, or open a file with the OS.
  final ValueChanged<PaneEntry> onOpen;

  final ValueChanged<PaneEntry> onToggleSelect;

  /// Right-click on desktop, long-press on touch.
  final void Function(PaneEntry entry, Offset globalPosition) onContextMenu;

  /// Entries dropped onto this pane from the other one. [targetDirectory] is
  /// the folder they landed on, which is this pane's own path unless the drop
  /// happened on a directory row.
  final void Function(PaneDragPayload payload, String targetDirectory)
      onDropped;

  /// Shown in place of the list when there is nothing in the folder.
  final String emptyMessage;

  /// Drops the modified/permission columns for narrow layouts.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _PaneHeader(
            side: side,
            title: title,
            subtitle: subtitle,
            crumbs: crumbs,
            canGoUp: canGoUp,
            loading: loading,
            onUp: onUp,
            onRefresh: onRefresh,
            onHome: onHome,
            onNewFolder: onNewFolder,
            onNavigate: onNavigate,
          ),
          if (error != null) _PaneError(message: error!, onRetry: onRefresh),
          Expanded(child: _buildBody(context, luma)),
          _PaneFooter(
            count: entries.length,
            selected: selection.length,
            luma: luma,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, LumaPalette luma) {
    final list = entries.isEmpty && !loading
        ? _PaneEmpty(message: error == null ? emptyMessage : 'Nothing to show.')
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _EntryRow(
                entry: entry,
                side: side,
                selected: selection.contains(entry.path),
                compact: compact,
                selectionForDrag: _dragEntries(entry),
                onOpen: () => onOpen(entry),
                onToggleSelect: () => onToggleSelect(entry),
                onContextMenu: (position) => onContextMenu(entry, position),
                onDroppedOnFolder: (payload) => onDropped(payload, entry.path),
              );
            },
          );

    // The whole body is a drop target for the other pane, so dropping
    // anywhere that isn't a folder row means "into the folder I'm looking at".
    return DragTarget<PaneDragPayload>(
      onWillAcceptWithDetails: (details) => details.data.side != side,
      onAcceptWithDetails: (details) => onDropped(details.data, path),
      builder: (context, candidate, rejected) {
        final active = candidate.isNotEmpty;
        return Stack(
          children: [
            Positioned.fill(child: list),
            if (loading)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(luma.accent),
                ),
              ),
            if (active)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      border: Border.all(color: luma.accent, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        side == PaneSide.remote
                            ? 'Upload to ${RemotePath.basename(path)}'
                            : 'Download to here',
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Dragging a row that is part of the selection moves the whole selection;
  /// dragging an unselected row moves just that row, the way a file manager
  /// behaves.
  List<PaneEntry> _dragEntries(PaneEntry entry) {
    if (!selection.contains(entry.path)) return [entry];
    return entries.where((e) => selection.contains(e.path)).toList();
  }
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({
    required this.side,
    required this.title,
    required this.subtitle,
    required this.crumbs,
    required this.canGoUp,
    required this.loading,
    required this.onUp,
    required this.onRefresh,
    required this.onHome,
    required this.onNewFolder,
    required this.onNavigate,
  });

  final PaneSide side;
  final String title;
  final String? subtitle;
  final List<({String label, String path})> crumbs;
  final bool canGoUp;
  final bool loading;
  final VoidCallback onUp;
  final VoidCallback onRefresh;
  final VoidCallback onHome;
  final VoidCallback onNewFolder;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                side == PaneSide.local
                    ? Icons.computer_rounded
                    : Icons.dns_rounded,
                size: 16,
                color: luma.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              _PaneAction(
                icon: Icons.arrow_upward_rounded,
                tooltip: 'Up one folder',
                onTap: canGoUp ? onUp : null,
              ),
              _PaneAction(
                icon: side == PaneSide.local
                    ? Icons.folder_special_rounded
                    : Icons.home_rounded,
                tooltip: side == PaneSide.local ? 'Places' : 'Home folder',
                onTap: onHome,
              ),
              _PaneAction(
                icon: Icons.create_new_folder_rounded,
                tooltip: 'New folder',
                onTap: onNewFolder,
              ),
              _PaneAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onTap: loading ? null : onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 26,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemCount: crumbs.length,
              itemBuilder: (context, index) {
                // Reversed so a long path keeps the current folder in view.
                final crumb = crumbs[crumbs.length - 1 - index];
                final isLast = index == 0;
                return Row(
                  children: [
                    if (!isLast)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: luma.textMuted,
                      ),
                    _Crumb(
                      label: crumb.label,
                      active: isLast,
                      onTap: isLast ? null : () => onNavigate(crumb.path),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.active, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: active ? luma.textPrimary : luma.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _PaneAction extends StatelessWidget {
  const _PaneAction({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        color: luma.textSecondary,
        disabledColor: luma.textMuted.withValues(alpha: 0.5),
        splashRadius: 18,
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
      ),
    );
  }
}

class _PaneError extends StatelessWidget {
  const _PaneError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      color: luma.danger.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: luma.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: luma.textPrimary, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry', style: TextStyle(color: luma.accent)),
          ),
        ],
      ),
    );
  }
}

class _PaneEmpty extends StatelessWidget {
  const _PaneEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: luma.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}

class _PaneFooter extends StatelessWidget {
  const _PaneFooter({
    required this.count,
    required this.selected,
    required this.luma,
  });

  final int count;
  final int selected;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: luma.border)),
      ),
      child: Text(
        selected > 0
            ? '$selected of $count selected'
            : '$count ${count == 1 ? 'item' : 'items'}',
        style: TextStyle(color: luma.textMuted, fontSize: 11),
      ),
    );
  }
}

class _EntryRow extends StatefulWidget {
  const _EntryRow({
    required this.entry,
    required this.side,
    required this.selected,
    required this.compact,
    required this.selectionForDrag,
    required this.onOpen,
    required this.onToggleSelect,
    required this.onContextMenu,
    required this.onDroppedOnFolder,
  });

  final PaneEntry entry;
  final PaneSide side;
  final bool selected;
  final bool compact;
  final List<PaneEntry> selectionForDrag;
  final VoidCallback onOpen;
  final VoidCallback onToggleSelect;
  final ValueChanged<Offset> onContextMenu;
  final ValueChanged<PaneDragPayload> onDroppedOnFolder;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entry = widget.entry;

    final row = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // No onDoubleTap here on purpose: pairing it with onTap makes every
        // single tap wait out the double-tap timeout before anything happens,
        // which is 300ms of dead air on the two most common actions. Folders
        // open on a tap, files select on a tap, and "Open" is in the context
        // menu for the files where it means something.
        onTap: entry.isDirectory ? widget.onOpen : widget.onToggleSelect,
        onLongPressStart: (details) =>
            widget.onContextMenu(details.globalPosition),
        onSecondaryTapDown: (details) =>
            widget.onContextMenu(details.globalPosition),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? luma.accentSubtle
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _SelectBox(
                selected: widget.selected,
                onTap: widget.onToggleSelect,
                label: entry.name,
              ),
              const SizedBox(width: 4),
              Icon(
                _iconFor(entry),
                size: 18,
                color: entry.isDirectory ? luma.accent : luma.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight:
                        entry.isDirectory ? FontWeight.w600 : FontWeight.w500,
                    fontStyle: entry.isLink ? FontStyle.italic : null,
                  ),
                ),
              ),
              if (!widget.compact && entry.permissions != null) ...[
                const SizedBox(width: 8),
                Text(
                  entry.permissions!,
                  style: TextStyle(
                    color: luma.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              if (!widget.compact) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 118,
                  child: Text(
                    _modifiedLabel(entry.modified),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              SizedBox(
                width: 66,
                child: Text(
                  entry.isDirectory ? '' : formatFileSize(entry.size),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final draggable = Draggable<PaneDragPayload>(
      data: PaneDragPayload(
        side: widget.side,
        entries: widget.selectionForDrag,
      ),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragFeedback(
        count: widget.selectionForDrag.length,
        label: widget.selectionForDrag.length == 1
            ? entry.name
            : '${widget.selectionForDrag.length} items',
        luma: luma,
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );

    if (!entry.isDirectory) return draggable;

    // Folders also accept drops, so you can transfer straight into a
    // subfolder without opening it first.
    return DragTarget<PaneDragPayload>(
      onWillAcceptWithDetails: (details) => details.data.side != widget.side,
      onAcceptWithDetails: (details) =>
          widget.onDroppedOnFolder(details.data),
      builder: (context, candidate, rejected) {
        if (candidate.isEmpty) return draggable;
        return Container(
          decoration: BoxDecoration(
            color: luma.accentSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.accent),
          ),
          child: draggable,
        );
      },
    );
  }

  static String _modifiedLabel(DateTime? modified) {
    if (modified == null) return '';
    final local = modified.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static IconData _iconFor(PaneEntry entry) {
    if (entry.isDirectory) return Icons.folder_rounded;
    final dot = entry.name.lastIndexOf('.');
    final extension =
        dot <= 0 ? '' : entry.name.substring(dot + 1).toLowerCase();
    return switch (extension) {
      'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'bmp' || 'svg' =>
        Icons.image_rounded,
      'mp4' || 'mkv' || 'mov' || 'avi' || 'webm' => Icons.movie_rounded,
      'mp3' || 'wav' || 'flac' || 'ogg' || 'm4a' => Icons.audiotrack_rounded,
      'zip' || 'gz' || 'tar' || 'rar' || '7z' || 'xz' => Icons.folder_zip_rounded,
      'pdf' => Icons.picture_as_pdf_rounded,
      'json' || 'yaml' || 'yml' || 'toml' || 'ini' || 'conf' || 'env' =>
        Icons.settings_rounded,
      'dart' || 'js' || 'ts' || 'py' || 'go' || 'rs' || 'java' || 'c' ||
      'cpp' || 'h' || 'sh' || 'php' || 'rb' =>
        Icons.code_rounded,
      'md' || 'txt' || 'log' || 'csv' => Icons.description_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.selected,
    required this.onTap,
    required this.label,
  });

  final bool selected;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      checked: selected,
      label: 'Select $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 32,
          height: 44,
          child: Center(
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: selected ? luma.accent : Colors.transparent,
                border: Border.all(
                  color: selected ? luma.accent : luma.border,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 12, color: luma.onAccent)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({
    required this.count,
    required this.label,
    required this.luma,
  });

  final int count;
  final String label;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: luma.accent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              count == 1
                  ? Icons.insert_drive_file_rounded
                  : Icons.file_copy_rounded,
              size: 15,
              color: luma.onAccent,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: luma.onAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
