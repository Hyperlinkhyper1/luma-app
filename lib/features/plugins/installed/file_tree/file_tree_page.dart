import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';

/// The File Tree plugin: point it at a drive or folder and it scans every file
/// underneath, then shows what's eating the space — directories and files
/// sorted largest-first, each with a size bar showing its share of the scan.
/// Think WizTree, living inside luma. Nothing is stored; each scan is live.
class FileTreePage extends StatefulWidget {
  const FileTreePage({super.key});

  @override
  State<FileTreePage> createState() => _FileTreePageState();
}

class _FileTreePageState extends State<FileTreePage> {
  bool _scanning = false;
  String? _error;
  FileNode? _root;

  /// Paths the user has expanded in the tree. The root starts expanded.
  final Set<String> _expanded = {};

  Future<void> _pickAndScan() async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a folder or drive to scan',
    );
    if (dir == null) return;
    await _scan(dir);
  }

  Future<void> _scan(String path) async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final root = await Isolate.run(() => _scanDirectory(path));
      if (!mounted) return;
      setState(() {
        _root = root;
        _expanded
          ..clear()
          ..add(root.path);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _toggle(FileNode node) {
    setState(() {
      if (_expanded.contains(node.path)) {
        _expanded.remove(node.path);
      } else {
        _expanded.add(node.path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScanBar(
            scanning: _scanning,
            root: _root,
            onPick: _pickAndScan,
            onScanPath: _scan,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text('$_error',
                style: TextStyle(color: context.luma.danger, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_scanning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            SizedBox(height: 14),
            Text('Scanning… this can take a moment on large drives.'),
          ],
        ),
      );
    }
    final root = _root;
    if (root == null) {
      return const LumaEmptyState(
        icon: Icons.account_tree_rounded,
        title: 'Nothing scanned yet',
        subtitle:
            'Pick a drive or folder above and luma will map out what\'s using the space.',
      );
    }
    if (root.totalSize == 0) {
      return const LumaEmptyState(
        icon: Icons.folder_off_rounded,
        title: 'This folder is empty',
        subtitle: 'No files were found, or they couldn\'t be read.',
      );
    }

    final rows = <_TreeRow>[];
    _flatten(root, 0, root.totalSize, rows);

    return LumaCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final row = rows[i];
          return _TreeTile(
            row: row,
            expanded: _expanded.contains(row.node.path),
            onToggle: () => _toggle(row.node),
          );
        },
      ),
    );
  }

  /// Walks the visible (expanded) tree into a flat, indented row list so the
  /// list can be virtualized. Children are already sorted largest-first.
  void _flatten(FileNode node, int depth, int rootTotal, List<_TreeRow> out) {
    out.add(_TreeRow(node: node, depth: depth, fraction: rootTotal == 0 ? 0 : node.totalSize / rootTotal));
    if (!_expanded.contains(node.path)) return;
    for (final child in node.children) {
      _flatten(child, depth + 1, rootTotal, out);
    }
  }
}

class _ScanBar extends StatelessWidget {
  const _ScanBar({
    required this.scanning,
    required this.root,
    required this.onPick,
    required this.onScanPath,
  });

  final bool scanning;
  final FileNode? root;
  final VoidCallback onPick;
  final ValueChanged<String> onScanPath;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LumaIconBadge(icon: Icons.account_tree_rounded, color: luma.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disk usage',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      root == null
                          ? 'See exactly what\'s filling up your drive.'
                          : root!.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (root != null) ...[
                LumaGhostButton(
                  label: 'Rescan',
                  icon: Icons.refresh_rounded,
                  onTap: scanning ? null : () => onScanPath(root!.path),
                ),
                const SizedBox(width: 8),
              ],
              LumaPrimaryButton(
                label: 'Choose folder',
                icon: Icons.create_new_folder_rounded,
                loading: scanning,
                onTap: scanning ? null : onPick,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DriveRow(onScanPath: scanning ? null : onScanPath),
          if (root != null) ...[
            const SizedBox(height: 14),
            Divider(color: luma.border, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(label: 'Total size', value: _formatBytes(root!.totalSize)),
                const SizedBox(width: 28),
                _Stat(label: 'Files', value: _formatCount(root!.fileCount)),
                const SizedBox(width: 28),
                _Stat(label: 'Folders', value: _formatCount(root!.dirCount)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Quick buttons for every fixed drive Windows currently has mounted.
class _DriveRow extends StatelessWidget {
  const _DriveRow({required this.onScanPath});
  final ValueChanged<String>? onScanPath;

  List<String> _drives() {
    final found = <String>[];
    for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++) {
      final path = '${String.fromCharCode(c)}:\\';
      if (Directory(path).existsSync()) found.add(path);
    }
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final drives = _drives();
    if (drives.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Drives',
            style: TextStyle(
                color: luma.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        for (final d in drives)
          _DriveChip(
            label: d.substring(0, 2),
            onTap: onScanPath == null ? null : () => onScanPath!(d),
          ),
      ],
    );
  }
}

class _DriveChip extends StatelessWidget {
  const _DriveChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storage_rounded, size: 15, color: luma.textSecondary),
              const SizedBox(width: 7),
              Text(label,
                  style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: luma.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: luma.textMuted, fontSize: 12)),
      ],
    );
  }
}

/// A node flattened for rendering, carrying its depth and share of the scan.
class _TreeRow {
  const _TreeRow({
    required this.node,
    required this.depth,
    required this.fraction,
  });
  final FileNode node;
  final int depth;
  final double fraction;
}

class _TreeTile extends StatefulWidget {
  const _TreeTile({
    required this.row,
    required this.expanded,
    required this.onToggle,
  });
  final _TreeRow row;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  State<_TreeTile> createState() => _TreeTileState();
}

class _TreeTileState extends State<_TreeTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final node = widget.row.node;
    final isDir = node.isDir;
    final hasChildren = node.children.isNotEmpty;
    final pct = (widget.row.fraction * 100);

    return MouseRegion(
      cursor: hasChildren ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: hasChildren ? widget.onToggle : null,
        child: Container(
          color: _hovering ? luma.surfaceHover : Colors.transparent,
          padding: EdgeInsets.only(
            left: 12 + widget.row.depth * 18.0,
            right: 14,
            top: 7,
            bottom: 7,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: hasChildren
                    ? Icon(
                        widget.expanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded,
                        size: 18,
                        color: luma.textMuted,
                      )
                    : null,
              ),
              Icon(
                isDir ? Icons.folder_rounded : Icons.insert_drive_file_rounded,
                size: 17,
                color: isDir ? luma.accent : luma.textMuted,
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 5,
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13.5,
                    fontWeight: isDir ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Size bar.
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.row.fraction.clamp(0.0, 1.0),
                          minHeight: 7,
                          backgroundColor: luma.border,
                          valueColor: AlwaysStoppedAnimation(
                            isDir ? luma.accent : luma.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 78,
                child: Text(
                  _formatBytes(node.totalSize),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan model + worker (runs in a background isolate via Isolate.run).
// ---------------------------------------------------------------------------

/// One entry in the scanned tree: a file or a directory with its rolled-up
/// total size. Directory [children] are sorted largest-first.
class FileNode {
  FileNode({
    required this.name,
    required this.path,
    required this.isDir,
    required this.totalSize,
    required this.fileCount,
    required this.dirCount,
    required this.children,
  });

  final String name;
  final String path;
  final bool isDir;
  final int totalSize;
  final int fileCount;
  final int dirCount;
  final List<FileNode> children;
}

/// Recursively measures [path]. Runs inside an isolate, so it uses the
/// synchronous IO APIs for speed and swallows entries it isn't allowed to read.
FileNode _scanDirectory(String path) {
  final dir = Directory(path);
  return _measure(dir, _displayName(path));
}

FileNode _measure(Directory dir, String name) {
  final children = <FileNode>[];
  var total = 0;
  var files = 0;
  var dirs = 0;

  List<FileSystemEntity> entries;
  try {
    entries = dir.listSync(followLinks: false);
  } catch (_) {
    entries = const [];
  }

  for (final entity in entries) {
    if (entity is File) {
      int size;
      try {
        size = entity.lengthSync();
      } catch (_) {
        continue;
      }
      total += size;
      files += 1;
      children.add(FileNode(
        name: _displayName(entity.path),
        path: entity.path,
        isDir: false,
        totalSize: size,
        fileCount: 0,
        dirCount: 0,
        children: const [],
      ));
    } else if (entity is Directory) {
      final child = _measure(entity, _displayName(entity.path));
      total += child.totalSize;
      files += child.fileCount;
      dirs += 1 + child.dirCount;
      children.add(child);
    }
  }

  children.sort((a, b) => b.totalSize.compareTo(a.totalSize));

  return FileNode(
    name: name,
    path: dir.path,
    isDir: true,
    totalSize: total,
    fileCount: files,
    dirCount: dirs,
    children: children,
  );
}

String _displayName(String path) {
  var p = path;
  // Drop a single trailing separator so "C:\" still shows as "C:\".
  while (p.length > 3 && (p.endsWith('\\') || p.endsWith('/'))) {
    p = p.substring(0, p.length - 1);
  }
  final slash = p.lastIndexOf(RegExp(r'[\\/]'));
  if (slash < 0 || slash == p.length - 1) return p;
  return p.substring(slash + 1);
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final digits = size >= 100 || unit == 0 ? 0 : (size >= 10 ? 1 : 2);
  return '${size.toStringAsFixed(digits)} ${units[unit]}';
}

String _formatCount(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
