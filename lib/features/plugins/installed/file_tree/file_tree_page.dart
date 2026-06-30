import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';

/// The File Tree plugin: point it at a drive or folder and it scans every file
/// underneath, then shows what's eating the space. Two views: a sortable tree
/// (directories/files largest-first with size bars) and a WizTree-style
/// treemap where each tile's area maps to its size. Nothing is stored; each
/// scan is live, and runs in a background isolate that streams progress.
class FileTreePage extends StatefulWidget {
  const FileTreePage({super.key});

  @override
  State<FileTreePage> createState() => _FileTreePageState();
}

class _FileTreePageState extends State<FileTreePage> {
  bool _scanning = false;
  String? _error;
  FileNode? _root;

  // Live progress, fed from the scan isolate.
  int _phase = 0; // 0 = indexing, 1 = measuring.
  int _scanned = 0;
  int _total = 0;
  int _bytes = 0;
  String _currentPath = '';

  // Running isolate handles, so a scan can be cancelled or cleaned up.
  Isolate? _iso;
  ReceivePort? _rp;

  // List view: paths the user has expanded. Treemap view: the drill-down path
  // from the scan root to the folder currently filling the canvas.
  final Set<String> _expanded = {};
  bool _detailed = false;
  List<FileNode> _crumbs = const [];

  // Detected once: probing drive letters does blocking I/O (a not-ready drive
  // can stall for seconds), so it must never run on every rebuild.
  late final List<String> _drives = _detectDrives();

  @override
  void dispose() {
    _cleanupScan();
    super.dispose();
  }

  Future<void> _cleanupScan() async {
    _rp?.close();
    _rp = null;
    _iso?.kill(priority: Isolate.immediate);
    _iso = null;
  }

  Future<void> _pickAndScan() async {
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose a folder or drive to scan',
    );
    if (dir == null) return;
    await _scan(dir);
  }

  Future<void> _scan(String path) async {
    await _cleanupScan();
    setState(() {
      _scanning = true;
      _error = null;
      _phase = 0;
      _scanned = 0;
      _total = 0;
      _bytes = 0;
      _currentPath = path;
    });

    final rp = ReceivePort();
    _rp = rp;
    try {
      _iso = await Isolate.spawn(_scanIsolate, _ScanArgs(rp.sendPort, path));
    } catch (e) {
      rp.close();
      if (mounted) {
        setState(() {
          _scanning = false;
          _error = '$e';
        });
      }
      return;
    }

    rp.listen((msg) {
      if (!mounted) return;
      if (msg is _ScanProgress) {
        setState(() {
          _phase = msg.phase;
          _scanned = msg.scanned;
          _total = msg.total;
          _bytes = msg.bytes;
          _currentPath = msg.path;
        });
      } else if (msg is _ScanResult) {
        setState(() {
          _root = msg.root;
          _crumbs = [msg.root];
          _expanded
            ..clear()
            ..add(msg.root.path);
          _scanning = false;
        });
        _cleanupScan();
      } else if (msg is _ScanError) {
        setState(() {
          _error = msg.message;
          _scanning = false;
        });
        _cleanupScan();
      }
    });
  }

  void _cancelScan() {
    _cleanupScan();
    if (mounted) setState(() => _scanning = false);
  }

  void _toggleExpand(FileNode node) {
    setState(() {
      if (!_expanded.remove(node.path)) _expanded.add(node.path);
    });
  }

  void _setView(bool detailed) {
    setState(() {
      _detailed = detailed;
      if (detailed && _crumbs.isEmpty && _root != null) _crumbs = [_root!];
    });
  }

  void _drill(FileNode node) {
    if (!node.isDir || node.children.isEmpty) return;
    setState(() => _crumbs = [..._crumbs, node]);
  }

  void _crumbTo(int index) {
    setState(() => _crumbs = _crumbs.sublist(0, index + 1));
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
            detailed: _detailed,
            drives: _drives,
            onPick: _pickAndScan,
            onScanPath: _scan,
            onSetView: _setView,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text('$_error',
                style: TextStyle(color: context.luma.danger, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Expanded(child: _body()),
          if (_scanning)
            _ScanProgressBar(
              phase: _phase,
              scanned: _scanned,
              total: _total,
              bytes: _bytes,
              path: _currentPath,
              onCancel: _cancelScan,
            ),
        ],
      ),
    );
  }

  Widget _body() {
    final root = _root;
    if (root == null) {
      if (_scanning) {
        return const _ScanningPlaceholder();
      }
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
    if (_detailed) {
      return _TreemapView(
        crumbs: _crumbs.isEmpty ? [root] : _crumbs,
        onDrill: _drill,
        onCrumb: _crumbTo,
      );
    }
    return _ListView(
      root: root,
      expanded: _expanded,
      onToggle: _toggleExpand,
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar: title, drive shortcuts, view toggle and scan summary.
// ---------------------------------------------------------------------------

class _ScanBar extends StatelessWidget {
  const _ScanBar({
    required this.scanning,
    required this.root,
    required this.detailed,
    required this.drives,
    required this.onPick,
    required this.onScanPath,
    required this.onSetView,
  });

  final bool scanning;
  final FileNode? root;
  final bool detailed;
  final List<String> drives;
  final VoidCallback onPick;
  final ValueChanged<String> onScanPath;
  final ValueChanged<bool> onSetView;

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
          _DriveRow(
            drives: drives,
            onScanPath: scanning ? null : onScanPath,
          ),
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
                const Spacer(),
                _ViewToggle(detailed: detailed, onSetView: onSetView),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Two-segment List / Detailed switch.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.detailed, required this.onSetView});
  final bool detailed;
  final ValueChanged<bool> onSetView;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          _ViewToggleButton(
            label: 'List',
            icon: Icons.format_list_bulleted_rounded,
            selected: !detailed,
            onTap: () => onSetView(false),
          ),
          const SizedBox(width: 3),
          _ViewToggleButton(
            label: 'Detailed',
            icon: Icons.grid_view_rounded,
            selected: detailed,
            onTap: () => onSetView(true),
          ),
        ],
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? luma.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? luma.onAccent : luma.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: selected ? luma.onAccent : luma.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick buttons for every fixed drive Windows currently has mounted. The
/// drive list is detected once by the parent and passed in — probing drive
/// letters is blocking I/O and must not run on every rebuild.
class _DriveRow extends StatelessWidget {
  const _DriveRow({required this.drives, required this.onScanPath});
  final List<String> drives;
  final ValueChanged<String>? onScanPath;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
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

class _ScanningPlaceholder extends StatelessWidget {
  const _ScanningPlaceholder();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bedtime_rounded, size: 34, color: luma.accent),
          const SizedBox(height: 14),
          Text('Mapping your files…',
              style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Progress is shown at the bottom.',
              style: TextStyle(color: luma.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom scan progress bar with the moon-tipped fill.
// ---------------------------------------------------------------------------

class _ScanProgressBar extends StatelessWidget {
  const _ScanProgressBar({
    required this.phase,
    required this.scanned,
    required this.total,
    required this.bytes,
    required this.path,
    required this.onCancel,
  });

  final int phase;
  final int scanned;
  final int total;
  final int bytes;
  final String path;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final indexing = phase == 0 || total <= 0;
    final fraction = indexing ? null : (scanned / total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                indexing ? 'Indexing files…' : 'Measuring sizes…',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                indexing
                    ? '${_formatCount(scanned)} items found'
                    : '${_formatCount(scanned)} / ${_formatCount(total)} items',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                '${_formatBytes(bytes)} scanned',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Cancel scan',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: luma.textMuted),
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _MoonProgressBar(fraction: fraction),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.description_outlined, size: 14, color: luma.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl, // keep the file name visible
                  style: TextStyle(
                    color: luma.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A horizontal progress track whose loaded/unloaded boundary is marked by a
/// glowing moon. With a [fraction] it's determinate; with null it sweeps as an
/// indeterminate scanning animation.
class _MoonProgressBar extends StatefulWidget {
  const _MoonProgressBar({required this.fraction});
  final double? fraction;

  @override
  State<_MoonProgressBar> createState() => _MoonProgressBarState();
}

class _MoonProgressBarState extends State<_MoonProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(); // forward-only sweep (no reverse), so it doesn't bounce back.

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fraction != null) return _bar(context, widget.fraction!);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => _bar(context, 0.04 + _ctrl.value * 0.92),
    );
  }

  Widget _bar(BuildContext context, double f) {
    final luma = context.luma;
    const moon = 22.0;
    const h = 24.0;
    return SizedBox(
      height: h,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final fillW = (f.clamp(0.0, 1.0)) * w;
          final moonLeft = (fillW - moon / 2).clamp(0.0, w - moon);
          return Stack(
            children: [
              // Track.
              Positioned(
                left: 0,
                right: 0,
                top: (h - 8) / 2,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: luma.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Filled portion.
              Positioned(
                left: 0,
                top: (h - 8) / 2,
                child: Container(
                  height: 8,
                  width: fillW,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [luma.accent, luma.accentHover],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // The moon at the boundary.
              Positioned(
                left: moonLeft,
                top: (h - moon) / 2,
                child: Container(
                  width: moon,
                  height: moon,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: luma.accent.withValues(alpha: 0.55),
                        blurRadius: 9,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bedtime_rounded,
                      size: moon, color: Color(0xFFFDF3C7)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List view (sortable expandable tree).
// ---------------------------------------------------------------------------

class _ListView extends StatelessWidget {
  const _ListView({
    required this.root,
    required this.expanded,
    required this.onToggle,
  });

  final FileNode root;
  final Set<String> expanded;
  final ValueChanged<FileNode> onToggle;

  void _flatten(FileNode node, int depth, int rootTotal, List<_TreeRow> out) {
    out.add(_TreeRow(
        node: node,
        depth: depth,
        fraction: rootTotal == 0 ? 0 : node.totalSize / rootTotal));
    if (!expanded.contains(node.path)) return;
    for (final child in node.children) {
      _flatten(child, depth + 1, rootTotal, out);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            expanded: expanded.contains(row.node.path),
            onToggle: () => onToggle(row.node),
          );
        },
      ),
    );
  }
}

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
    final pct = widget.row.fraction * 100;

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
                    fontFeatures: const [FontFeature.tabularFigures()],
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
// Treemap view (WizTree-style: tile area maps to file size).
// ---------------------------------------------------------------------------

class _TreemapView extends StatelessWidget {
  const _TreemapView({
    required this.crumbs,
    required this.onDrill,
    required this.onCrumb,
  });

  final List<FileNode> crumbs;
  final ValueChanged<FileNode> onDrill;
  final ValueChanged<int> onCrumb;

  @override
  Widget build(BuildContext context) {
    final node = crumbs.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Breadcrumb(crumbs: crumbs, onCrumb: onCrumb),
        const SizedBox(height: 10),
        Expanded(
          child: LumaCard(
            padding: const EdgeInsets.all(6),
            child: node.children.isEmpty
                ? const Center(child: Text('No files to map in this folder.'))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _TreemapNode(node: node, depth: 0, onDrill: onDrill),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Children of [node] for the treemap, capped so the canvas never renders
/// thousands of slivers — the long tail is folded into one aggregate tile.
List<FileNode> _tileChildren(FileNode node) {
  final ch = node.children.where((c) => c.totalSize > 0).toList();
  if (ch.length <= 80) return ch;
  final head = ch.sublist(0, 79);
  final restSize = ch.sublist(79).fold<int>(0, (s, c) => s + c.totalSize);
  head.add(FileNode(
    name: '(${ch.length - 79} smaller items)',
    path: '${node.path}::more',
    isDir: false,
    totalSize: restSize,
    fileCount: 0,
    dirCount: 0,
    children: const [],
  ));
  return head;
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.crumbs, required this.onCrumb});
  final List<FileNode> crumbs;
  final ValueChanged<int> onCrumb;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      spacing: 2,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < crumbs.length; i++) ...[
          _CrumbButton(
            label: crumbs[i].name,
            isLast: i == crumbs.length - 1,
            onTap: i == crumbs.length - 1 ? null : () => onCrumb(i),
          ),
          if (i != crumbs.length - 1)
            Icon(Icons.chevron_right_rounded,
                size: 16, color: luma.textMuted),
        ],
      ],
    );
  }
}

class _CrumbButton extends StatelessWidget {
  const _CrumbButton({
    required this.label,
    required this.isLast,
    required this.onTap,
  });
  final String label;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            label,
            style: TextStyle(
              color: isLast ? luma.textPrimary : luma.accent,
              fontSize: 13,
              fontWeight: isLast ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Deepest level of nesting drawn. Recursion also stops earlier when tiles get
/// too small to be worth subdividing, so this is just a safety bound.
const int _maxTreemapDepth = 7;

/// One node of the WizTree-style nested treemap. A directory that's large
/// enough is drawn as its folder color with a small header, then its children
/// are squarified into the remaining area and drawn recursively — so the whole
/// hierarchy is visible at once. Small nodes and files render as solid tiles.
class _TreemapNode extends StatelessWidget {
  const _TreemapNode({
    required this.node,
    required this.depth,
    required this.onDrill,
  });

  final FileNode node;
  final int depth;
  final ValueChanged<FileNode> onDrill;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        if (w < 2 || h < 2) return const SizedBox.shrink();

        final hasKids = node.isDir && node.children.isNotEmpty;
        final canNest =
            hasKids && depth < _maxTreemapDepth && w > 70 && h > 58;

        if (!canNest) {
          return _LeafTile(
            node: node,
            color: _tileColor(node, brightness),
            onTap: hasKids ? () => onDrill(node) : null,
          );
        }

        final fill = _tileColor(node, brightness);
        final onFill = _onColor(fill);
        final headerH = depth == 0 ? 0.0 : (h > 70 ? 20.0 : 0.0);
        const pad = 2.0;
        final tiles = _squarify(
          _tileChildren(node),
          Size(w - pad * 2, h - headerH - pad * 2),
        );

        return Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(depth == 0 ? 0 : 4),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.22),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              if (headerH > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: headerH,
                  child: _FolderHeader(
                    node: node,
                    onColor: onFill,
                    onTap: () => onDrill(node),
                  ),
                ),
              for (final t in tiles)
                Positioned(
                  left: pad + t.rect.left,
                  top: headerH + pad + t.rect.top,
                  width: math.max(0, t.rect.width),
                  height: math.max(0, t.rect.height),
                  child: _TreemapNode(
                    node: t.node,
                    depth: depth + 1,
                    onDrill: onDrill,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A solid leaf tile (a file, or a folder too small to subdivide further).
class _LeafTile extends StatefulWidget {
  const _LeafTile({
    required this.node,
    required this.color,
    required this.onTap,
  });
  final FileNode node;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<_LeafTile> createState() => _LeafTileState();
}

class _LeafTileState extends State<_LeafTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final onFill = _onColor(widget.color);

    return Tooltip(
      message: '${node.name}\n${_formatBytes(node.totalSize)}',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: _hovering
                    ? Colors.white
                    : Colors.black.withValues(alpha: 0.18),
                width: _hovering ? 1.5 : 0.5,
              ),
            ),
            clipBehavior: Clip.hardEdge,
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth < 40 || c.maxHeight < 22) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            node.isDir
                                ? Icons.folder_rounded
                                : Icons.insert_drive_file_rounded,
                            size: 12,
                            color: onFill.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              node.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: onFill,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (c.maxHeight > 38) ...[
                        const SizedBox(height: 1),
                        Text(
                          _formatBytes(node.totalSize),
                          style: TextStyle(
                            color: onFill.withValues(alpha: 0.85),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The title strip on top of a nested folder tile.
class _FolderHeader extends StatefulWidget {
  const _FolderHeader({
    required this.node,
    required this.onColor,
    required this.onTap,
  });
  final FileNode node;
  final Color onColor;
  final VoidCallback onTap;

  @override
  State<_FolderHeader> createState() => _FolderHeaderState();
}

class _FolderHeaderState extends State<_FolderHeader> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final onColor = widget.onColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hovering
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.10),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Icon(Icons.folder_rounded,
                  size: 12, color: onColor.withValues(alpha: 0.9)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatBytes(widget.node.totalSize),
                style: TextStyle(
                  color: onColor.withValues(alpha: 0.85),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _onColor(Color fill) =>
    fill.computeLuminance() > 0.5 ? const Color(0xFF1A1526) : Colors.white;

/// Stable per-name hue so the same folder always gets the same tile color,
/// tuned for legible text in both themes (folders read a touch brighter).
Color _tileColor(FileNode node, Brightness brightness) {
  final hue = (node.name.hashCode % 360).abs().toDouble();
  final dark = brightness == Brightness.dark;
  final sat = dark ? 0.42 : 0.55;
  final light = dark ? (node.isDir ? 0.52 : 0.40) : (node.isDir ? 0.60 : 0.72);
  return HSLColor.fromAHSL(1, hue, sat, light).toColor();
}

class _TileLayout {
  const _TileLayout(this.node, this.rect);
  final FileNode node;
  final Rect rect;
}

/// Squarified treemap: lays [nodes] (sorted largest-first) into [size] so tile
/// area is proportional to size while keeping aspect ratios close to square.
List<_TileLayout> _squarify(List<FileNode> nodes, Size size) {
  final out = <_TileLayout>[];
  final items = nodes.where((n) => n.totalSize > 0).toList();
  if (items.isEmpty || size.width <= 0 || size.height <= 0) return out;

  final totalSize = items.fold<double>(0, (s, n) => s + n.totalSize);
  final totalArea = size.width * size.height;
  final areas =
      items.map((n) => n.totalSize / totalSize * totalArea).toList();

  var rect = Rect.fromLTWH(0, 0, size.width, size.height);
  var start = 0;
  while (start < areas.length) {
    final shortSide = math.min(rect.width, rect.height);
    if (shortSide <= 0) break;

    var end = start;
    var rowSum = 0.0;
    var rowMin = double.infinity;
    var rowMax = 0.0;
    var bestWorst = double.infinity;
    var chosenEnd = start;
    var chosenSum = 0.0;

    while (end < areas.length) {
      final a = areas[end];
      final nSum = rowSum + a;
      final nMin = math.min(rowMin, a);
      final nMax = math.max(rowMax, a);
      final s2 = shortSide * shortSide;
      final worst = math.max(s2 * nMax / (nSum * nSum), nSum * nSum / (s2 * nMin));
      if (end == start || worst <= bestWorst) {
        bestWorst = worst;
        rowSum = nSum;
        rowMin = nMin;
        rowMax = nMax;
        end++;
        chosenEnd = end;
        chosenSum = rowSum;
      } else {
        break;
      }
    }

    rect = _placeRow(items, areas, start, chosenEnd, chosenSum, rect, out);
    start = chosenEnd;
  }
  return out;
}

Rect _placeRow(List<FileNode> items, List<double> areas, int start, int end,
    double sum, Rect rect, List<_TileLayout> out) {
  if (sum <= 0) return rect;
  if (rect.width >= rect.height) {
    final colW = sum / rect.height;
    var y = rect.top;
    for (var i = start; i < end; i++) {
      final h = areas[i] / colW;
      out.add(_TileLayout(items[i], Rect.fromLTWH(rect.left, y, colW, h)));
      y += h;
    }
    return Rect.fromLTWH(
        rect.left + colW, rect.top, rect.width - colW, rect.height);
  } else {
    final rowH = sum / rect.width;
    var x = rect.left;
    for (var i = start; i < end; i++) {
      final w = areas[i] / rowH;
      out.add(_TileLayout(items[i], Rect.fromLTWH(x, rect.top, w, rowH)));
      x += w;
    }
    return Rect.fromLTWH(
        rect.left, rect.top + rowH, rect.width, rect.height - rowH);
  }
}

// ---------------------------------------------------------------------------
// Scan model + worker (runs in a background isolate, streaming progress).
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

class _ScanArgs {
  const _ScanArgs(this.sendPort, this.path);
  final SendPort sendPort;
  final String path;
}

class _ScanProgress {
  const _ScanProgress({
    required this.phase,
    required this.scanned,
    required this.total,
    required this.bytes,
    required this.path,
  });
  final int phase; // 0 = indexing, 1 = measuring.
  final int scanned;
  final int total;
  final int bytes;
  final String path;
}

class _ScanResult {
  const _ScanResult(this.root);
  final FileNode root;
}

class _ScanError {
  const _ScanError(this.message);
  final String message;
}

/// Mutable counters shared across the recursive walk, plus throttled posting
/// so the port isn't flooded (progress is sent at most ~every 50ms).
class _Holder {
  _Holder(this.send);
  final SendPort send;
  int total = 0;
  int scanned = 0;
  int bytes = 0;
  final Stopwatch sw = Stopwatch()..start();
  int lastMs = -1000;

  void maybePost(int phase, String path) {
    final ms = sw.elapsedMilliseconds;
    if (ms - lastMs < 50) return;
    lastMs = ms;
    send.send(_ScanProgress(
      phase: phase,
      scanned: phase == 0 ? total : scanned,
      total: total,
      bytes: bytes,
      path: path,
    ));
  }
}

void _scanIsolate(_ScanArgs a) {
  final h = _Holder(a.sendPort);
  try {
    a.sendPort.send(_ScanProgress(
        phase: 0, scanned: 0, total: 0, bytes: 0, path: a.path));
    // Phase 1: count items (no per-file stat, so it's cheap) for a real total.
    _count(Directory(a.path), h);
    // Phase 2: measure sizes and build the tree, streaming determinate progress.
    h.lastMs = -1000;
    final root = _measure(Directory(a.path), _displayName(a.path), h);
    a.sendPort.send(_ScanResult(root));
  } catch (e) {
    a.sendPort.send(_ScanError('$e'));
  }
}

void _count(Directory dir, _Holder h) {
  List<FileSystemEntity> entries;
  try {
    entries = dir.listSync(followLinks: false);
  } catch (_) {
    return;
  }
  for (final e in entries) {
    h.total++;
    if (e is Directory) {
      h.maybePost(0, e.path);
      _count(e, h);
    }
  }
}

FileNode _measure(Directory dir, String name, _Holder h) {
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
      h.scanned++;
      int size;
      try {
        size = entity.lengthSync();
      } catch (_) {
        continue;
      }
      total += size;
      files += 1;
      h.bytes += size;
      h.maybePost(1, entity.path);
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
      h.scanned++;
      h.maybePost(1, entity.path);
      final child = _measure(entity, _displayName(entity.path), h);
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
    children: _capChildren(children, dir.path),
  );
}

/// The biggest source of the post-scan freeze is shipping the whole node graph
/// back across the isolate boundary — millions of file nodes take minutes to
/// deserialize on the UI thread. We only ever display a directory's largest
/// children, so we keep the top [_maxChildrenPerDir] by size and fold the long
/// tail into a single aggregate node. The directory's own totals were already
/// rolled up from every entry, so sizes and percentages stay exact.
const int _maxChildrenPerDir = 200;

List<FileNode> _capChildren(List<FileNode> sorted, String parentPath) {
  if (sorted.length <= _maxChildrenPerDir) return sorted;
  final head = sorted.sublist(0, _maxChildrenPerDir - 1);
  final rest = sorted.sublist(_maxChildrenPerDir - 1);
  final restSize = rest.fold<int>(0, (s, c) => s + c.totalSize);
  head.add(FileNode(
    name: '(${rest.length} more items)',
    path: '$parentPath::more',
    isDir: false,
    totalSize: restSize,
    fileCount: 0,
    dirCount: 0,
    children: const [],
  ));
  return head;
}

/// Probes A:–Z: for mounted drives. Synchronous and potentially slow (a
/// not-ready drive can stall), so call this once and cache the result.
List<String> _detectDrives() {
  final found = <String>[];
  for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++) {
    final path = '${String.fromCharCode(c)}:\\';
    try {
      // existsSync throws (not returns false) for a mapped-but-not-ready
      // drive — an empty card reader or optical drive, etc. Skip those.
      if (Directory(path).existsSync()) found.add(path);
    } catch (_) {
      // Drive letter present but not ready; ignore it.
    }
  }
  return found;
}

String _displayName(String path) {
  var p = path;
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
