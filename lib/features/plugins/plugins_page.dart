import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../theme/luma_theme.dart';
import 'plugin_catalog_service.dart';
import 'plugin_icons.dart';
import 'plugin_repository.dart';
import 'plugin_scope.dart';

/// The Plugins marketplace: a Modrinth-style grid fetched live from the
/// luma-app GitHub repo's `plugins/` folder. Nothing here is bundled in the
/// app — a plugin only becomes usable (and gets its own nav rail icon) once
/// the user downloads it.
class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key, required this.onOpenPlugin});

  /// Called with a plugin id when the user opens an already-installed plugin.
  final ValueChanged<String> onOpenPlugin;

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  final _service = PluginCatalogService();
  late Future<List<PluginCatalogEntry>> _catalog = _service.fetchCatalog();

  @override
  Widget build(BuildContext context) {
    final repo = PluginScope.of(context);

    return StreamBuilder<List<InstalledPluginRecord>>(
      stream: repo.watchInstalled(),
      builder: (context, installedSnap) {
        final installedIds = (installedSnap.data ?? const [])
            .map((p) => p.pluginId)
            .toSet();

        return FutureBuilder<List<PluginCatalogEntry>>(
          future: _catalog,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              );
            }
            if (snap.hasError) {
              return LumaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load the plugin catalog',
                subtitle: '${snap.error}',
                action: LumaGhostButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onTap: () => setState(() => _catalog = _service.fetchCatalog()),
                ),
              );
            }
            final plugins = snap.data ?? const [];
            if (plugins.isEmpty) {
              return const LumaEmptyState(
                icon: Icons.extension_rounded,
                title: 'No plugins available yet',
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisExtent: 206,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: plugins.length,
                itemBuilder: (context, i) {
                  final entry = plugins[i];
                  return _PluginTile(
                    entry: entry,
                    installed: installedIds.contains(entry.id),
                    repo: repo,
                    onOpen: () => widget.onOpenPlugin(entry.id),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _PluginTile extends StatefulWidget {
  const _PluginTile({
    required this.entry,
    required this.installed,
    required this.repo,
    required this.onOpen,
  });

  final PluginCatalogEntry entry;
  final bool installed;
  final PluginRepository repo;
  final VoidCallback onOpen;

  @override
  State<_PluginTile> createState() => _PluginTileState();
}

class _PluginTileState extends State<_PluginTile> {
  bool _hovering = false;
  bool _installing = false;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await widget.repo.install(widget.entry);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entry = widget.entry;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovering
                ? luma.accent.withValues(alpha: 0.5)
                : luma.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LumaIconBadge(
                  icon: pluginIconFor(entry.icon),
                  color: luma.accent,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _CategoryChip(label: entry.category, luma: luma),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                entry.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.danger, fontSize: 11),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: widget.installed
                      ? LumaGhostButton(
                          label: 'Open',
                          icon: Icons.open_in_new_rounded,
                          onTap: widget.onOpen,
                        )
                      : LumaPrimaryButton(
                          label: 'Download',
                          icon: Icons.download_rounded,
                          loading: _installing,
                          onTap: _install,
                        ),
                ),
                if (widget.installed) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Remove plugin',
                    child: IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: luma.textMuted, size: 20),
                      onPressed: () => widget.repo.uninstall(entry.id),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.luma});
  final String label;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: luma.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
