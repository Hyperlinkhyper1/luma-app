import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'map_maker_models.dart';
import 'map_maker_store.dart';

class MapMakerSavesView extends StatelessWidget {
  const MapMakerSavesView({
    super.key,
    required this.onBack,
    required this.onOpenSave,
    required this.onNewTransitMap,
  });

  final VoidCallback onBack;
  final ValueChanged<MapMakerSave> onOpenSave;
  final VoidCallback onNewTransitMap;

  Future<void> _renameSave(BuildContext context, MapMakerSave save) async {
    final controller = TextEditingController(text: save.title);
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Rename Map', style: TextStyle(color: luma.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: luma.textPrimary),
          decoration: InputDecoration(
            labelText: 'Map Name',
            labelStyle: TextStyle(color: luma.textSecondary),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: luma.accent),
            ),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: luma.accent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Save', style: TextStyle(color: luma.onAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await MapMakerStore.instance.rename(save.id, controller.text.trim());
    }
  }

  Future<void> _deleteSave(BuildContext context, MapMakerSave save) async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Delete Map?', style: TextStyle(color: luma.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${save.title}"? This cannot be undone.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: luma.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await MapMakerStore.instance.delete(save.id);
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final isPhone = context.isPhoneWidth;

    return Scaffold(
      backgroundColor: luma.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isPhone ? 12 : 24,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: luma.surface,
            border: Border(bottom: BorderSide(color: luma.border)),
          ),
          child: Row(
            children: [
              LumaGhostButton(
                icon: Icons.arrow_back_rounded,
                label: 'Menu',
                onTap: onBack,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Saved Maps',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              LumaPrimaryButton(
                icon: Icons.add_rounded,
                label: 'New Transit Map',
                onTap: onNewTransitMap,
              ),
            ],
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: MapMakerStore.instance,
        builder: (context, _) {
          final saves = MapMakerStore.instance.saves;

          if (saves.isEmpty) {
            return Center(
              child: LumaEmptyState(
                icon: Icons.map_outlined,
                title: 'No saved maps yet',
                subtitle:
                    'Start designing custom fantasy transit maps with octilinear lines, stations, and rivers.',
                action: LumaPrimaryButton(
                  icon: Icons.add_rounded,
                  label: 'Create First Map',
                  onTap: onNewTransitMap,
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isPhone ? 16 : 32,
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${saves.length} ${saves.length == 1 ? 'Project' : 'Projects'}',
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth < 600
                            ? 1
                            : (constraints.maxWidth < 900 ? 2 : 3);
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 200,
                          ),
                          itemCount: saves.length,
                          itemBuilder: (context, index) {
                            final save = saves[index];
                            return _SaveCard(
                              save: save,
                              formattedDate: _formatDate(save.updatedAt),
                              onOpen: () => onOpenSave(save),
                              onRename: () => _renameSave(context, save),
                              onDelete: () => _deleteSave(context, save),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SaveCard extends StatefulWidget {
  const _SaveCard({
    required this.save,
    required this.formattedDate,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final MapMakerSave save;
  final String formattedDate;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  State<_SaveCard> createState() => _SaveCardState();
}

class _SaveCardState extends State<_SaveCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final transit = widget.save.transit;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _hovering ? luma.surfaceHover : luma.surface,
          borderRadius: decor.cardBorderRadius,
          border: Border.all(
            color: _hovering
                ? luma.accent.withValues(alpha: 0.6)
                : luma.border,
            width: decor.borderWidth,
          ),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: luma.accent.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : decor.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0077C0).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.alt_route_rounded,
                        color: Color(0xFF0077C0),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.save.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Transit Map • ${widget.formattedDate}',
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: luma.textMuted,
                        size: 18,
                      ),
                      color: luma.surface,
                      onSelected: (value) {
                        if (value == 'rename') widget.onRename();
                        if (value == 'delete') widget.onDelete();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 16, color: luma.textSecondary),
                              const SizedBox(width: 8),
                              Text('Rename', style: TextStyle(color: luma.textPrimary)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, size: 16, color: luma.danger),
                              const SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: luma.danger)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stats row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: luma.surfaceHover,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${transit.stations.length} stops',
                        style: TextStyle(color: luma.textSecondary, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: luma.surfaceHover,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${transit.lines.length} lines',
                        style: TextStyle(color: luma.textSecondary, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Line color dots
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        children: [
                          for (final line in transit.lines.take(6))
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(line.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: LumaPrimaryButton(
                    label: 'Open',
                    icon: Icons.open_in_browser_rounded,
                    onTap: widget.onOpen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
