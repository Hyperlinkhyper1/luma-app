import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/modrinth_api_client.dart';

// ── Formatting ──────────────────────────────────────────────────────────

/// 254288940 → "254.3M". Modrinth prints download counts this way and the
/// raw number is unreadable at card size.
String formatCompactCount(int value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

String relativeTime(DateTime? time) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time);
  if (diff.inDays >= 365) {
    final years = diff.inDays ~/ 365;
    return '$years year${years == 1 ? '' : 's'} ago';
  }
  if (diff.inDays >= 30) {
    final months = diff.inDays ~/ 30;
    return '$months month${months == 1 ? '' : 's'} ago';
  }
  if (diff.inDays >= 1) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'just now';
}

/// `worldgen` → `Worldgen`, `game-mechanics` → `Game mechanics`.
String prettyTag(String raw) {
  if (raw.isEmpty) return raw;
  final spaced = raw.replaceAll('-', ' ').replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// Modrinth prints a small glyph next to each category tag. These are the
/// closest Material equivalents; anything unmapped falls back to a label.
IconData modrinthTagIcon(String tag) => switch (tag) {
      'adventure' => Icons.explore_rounded,
      'cursed' => Icons.sentiment_very_dissatisfied_rounded,
      'decoration' => Icons.chair_rounded,
      'economy' => Icons.payments_rounded,
      'equipment' => Icons.shield_rounded,
      'food' => Icons.restaurant_rounded,
      'game-mechanics' => Icons.settings_suggest_rounded,
      'library' => Icons.inventory_2_rounded,
      'magic' => Icons.auto_fix_high_rounded,
      'management' => Icons.tune_rounded,
      'minigame' => Icons.sports_esports_rounded,
      'mobs' => Icons.pets_rounded,
      'optimization' => Icons.speed_rounded,
      'social' => Icons.forum_rounded,
      'storage' => Icons.warehouse_rounded,
      'technology' => Icons.memory_rounded,
      'transportation' => Icons.directions_transit_rounded,
      'utility' => Icons.handyman_rounded,
      'worldgen' => Icons.public_rounded,
      'realistic' => Icons.photo_camera_rounded,
      'simplistic' => Icons.crop_square_rounded,
      'themed' => Icons.palette_rounded,
      'vanilla-like' => Icons.grass_rounded,
      'combat' => Icons.sports_martial_arts_rounded,
      'fantasy' => Icons.castle_rounded,
      'atmosphere' => Icons.wb_twilight_rounded,
      'bloom' => Icons.blur_on_rounded,
      'colored-lighting' => Icons.lightbulb_rounded,
      'path-tracing' => Icons.flare_rounded,
      'pbr' => Icons.texture_rounded,
      'reflections' => Icons.water_rounded,
      'shadows' => Icons.dark_mode_rounded,
      'semi-realistic' => Icons.landscape_rounded,
      'cartoon' => Icons.brush_rounded,
      'audio' => Icons.graphic_eq_rounded,
      'fonts' => Icons.text_fields_rounded,
      'models' => Icons.view_in_ar_rounded,
      'tweaks' => Icons.build_rounded,
      _ => Icons.label_rounded,
    };

IconData contentKindIcon(String kind) => switch (kind) {
      'resourcepack' => Icons.palette_rounded,
      'shader' => Icons.light_mode_rounded,
      'datapack' => Icons.data_object_rounded,
      _ => Icons.extension_rounded,
    };

/// Modrinth ships an accent colour sampled from each project's icon. It is
/// lovely as a soft wash behind the icon, but arbitrary hues fail contrast
/// as text, so it is only ever used as a tint here.
Color? modrinthAccentOf(int? packedRgb) =>
    packedRgb == null ? null : Color(0xFF000000 | packedRgb);

// ── Primitives ──────────────────────────────────────────────────────────

/// A project icon: rounded, bordered, tinted with the project's own accent
/// while it loads, and falling back to a kind glyph when there is no icon.
class ModrinthThumb extends StatelessWidget {
  const ModrinthThumb({
    super.key,
    required this.url,
    required this.kind,
    this.size = 64,
    this.accent,
    this.radius,
  });

  final String? url;
  final String kind;
  final double size;
  final Color? accent;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final tint = accent ?? luma.accent;
    final corner = radius ?? size * 0.22;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(corner),
        border: Border.all(color: luma.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Icon(contentKindIcon(kind), color: tint, size: size * 0.46)
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Most Minecraft project icons are small pixel art; smoothing
              // them turns crisp 64px sprites into mush.
              filterQuality: FilterQuality.none,
              errorBuilder: (_, _, _) =>
                  Icon(contentKindIcon(kind), color: tint, size: size * 0.46),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Center(
                      child: SizedBox(
                        width: size * 0.3,
                        height: size * 0.3,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(tint.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
            ),
    );
  }
}

/// A category pill — glyph + label, the way Modrinth tags a card.
class ModrinthTag extends StatelessWidget {
  const ModrinthTag({super.key, required this.label, this.icon, this.tone});
  final String label;
  final IconData? icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = tone ?? luma.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Icon + number, used for downloads / followers / updated-at.
class ModrinthStat extends StatelessWidget {
  const ModrinthStat({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.emphasis = false,
  });

  final IconData icon;
  final String value;
  final String? label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: luma.textMuted),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: emphasis ? luma.textPrimary : luma.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 4),
          Text(label!, style: TextStyle(color: luma.textMuted, fontSize: 12)),
        ],
      ],
    );
  }
}

/// The install affordance shared by tiles and the detail header: a compact
/// pill that carries its own idle / busy / installed states so a caller only
/// has to say which one it is in.
class ModrinthInstallButton extends StatefulWidget {
  const ModrinthInstallButton({
    super.key,
    required this.onInstall,
    this.installed = false,
    this.busy = false,
    this.compact = true,
    this.label = 'Install',
    this.tooltip,
  });

  final Future<void> Function()? onInstall;
  final bool installed;
  final bool busy;
  final bool compact;
  final String label;
  final String? tooltip;

  @override
  State<ModrinthInstallButton> createState() => _ModrinthInstallButtonState();
}

class _ModrinthInstallButtonState extends State<ModrinthInstallButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final installed = widget.installed;
    final enabled = widget.onInstall != null && !widget.busy && !installed;

    final background = installed
        ? luma.success.withValues(alpha: 0.16)
        : enabled
            ? (_hovering ? luma.accentHover : luma.accent)
            : luma.accent.withValues(alpha: 0.35);
    final foreground = installed ? luma.success : luma.onAccent;
    final icon = installed
        ? Icons.check_rounded
        : widget.compact
            ? Icons.add_rounded
            : Icons.download_rounded;

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: widget.compact ? 34 : 40,
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: decor.buttonBorderRadius,
        border: installed
            ? Border.all(color: luma.success.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.busy)
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(foreground),
              ),
            )
          else
            Icon(icon, size: widget.compact ? 18 : 18, color: foreground),
          if (!widget.compact) ...[
            const SizedBox(width: 8),
            Text(
              installed ? 'Installed' : widget.label,
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: widget.tooltip ?? (installed ? 'Already installed' : widget.label),
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: enabled ? () => widget.onInstall?.call() : null,
          child: child,
        ),
      ),
    );
  }
}

// ── The card ────────────────────────────────────────────────────────────

/// A Modrinth-style search result: icon, title + author, summary, category
/// tags, and download/follow/updated stats, with a one-tap install on the
/// right. Collapses to a stacked layout on narrow panes.
class ModrinthProjectTile extends StatefulWidget {
  const ModrinthProjectTile({
    super.key,
    required this.hit,
    required this.onOpen,
    this.onInstall,
    this.installed = false,
    this.installing = false,
    this.installTooltip,
    this.dense = false,
  });

  final ModrinthSearchHit hit;
  final VoidCallback onOpen;
  final Future<void> Function()? onInstall;
  final bool installed;
  final bool installing;
  final String? installTooltip;

  /// A tighter variant for embedding in a list next to other content (the
  /// global search page), without the tag row.
  final bool dense;

  @override
  State<ModrinthProjectTile> createState() => _ModrinthProjectTileState();
}

class _ModrinthProjectTileState extends State<ModrinthProjectTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final hit = widget.hit;
    final accent = modrinthAccentOf(hit.color) ?? luma.accent;
    final tags = (hit.displayCategories.isEmpty ? hit.categories : hit.displayCategories)
        .take(4)
        .toList();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(widget.dense ? 12 : 16),
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : luma.surface,
            borderRadius: decor.cardBorderRadius,
            border: Border.all(
              color: _hovering
                  ? Color.lerp(luma.border, accent, 0.55)!
                  : luma.border,
              width: decor.borderWidth,
            ),
            boxShadow: _hovering ? decor.cardShadow : const [],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 520;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ModrinthThumb(
                    url: hit.iconUrl,
                    kind: hit.projectType,
                    accent: accent,
                    size: widget.dense ? 44 : 64,
                  ),
                  SizedBox(width: widget.dense ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _titleLine(luma),
                        const SizedBox(height: 4),
                        Text(
                          hit.description,
                          maxLines: widget.dense ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: luma.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        if (!widget.dense) ...[
                          const SizedBox(height: 10),
                          if (wide)
                            Row(
                              children: [
                                Expanded(child: _tagRow(tags)),
                                const SizedBox(width: 12),
                                _statRow(luma),
                              ],
                            )
                          else ...[
                            _tagRow(tags),
                            const SizedBox(height: 8),
                            _statRow(luma),
                          ],
                        ],
                      ],
                    ),
                  ),
                  if (widget.onInstall != null) ...[
                    const SizedBox(width: 12),
                    ModrinthInstallButton(
                      onInstall: widget.onInstall,
                      installed: widget.installed,
                      busy: widget.installing,
                      tooltip: widget.installTooltip,
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: luma.textMuted),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _titleLine(LumaPalette luma) {
    final hit = widget.hit;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            hit.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: widget.dense ? 14 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (hit.author != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'by ${hit.author}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tagRow(List<String> tags) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          ModrinthTag(label: prettyTag(tag), icon: modrinthTagIcon(tag)),
      ],
    );
  }

  Widget _statRow(LumaPalette luma) {
    final hit = widget.hit;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ModrinthStat(
          icon: Icons.download_rounded,
          value: formatCompactCount(hit.downloads),
          emphasis: true,
        ),
        const SizedBox(width: 14),
        ModrinthStat(
          icon: Icons.favorite_rounded,
          value: formatCompactCount(hit.follows),
        ),
        if (hit.dateModified != null) ...[
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              'Updated ${relativeTime(hit.dateModified)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Instance picker ─────────────────────────────────────────────────────

/// Asks which instance a project should land in. Returns null if dismissed.
/// Skips the sheet entirely when there is only one instance — picking from a
/// list of one is friction, not a choice.
Future<McInstance?> pickInstance(
  BuildContext context,
  List<McInstance> instances, {
  String title = 'Install into which instance?',
  String? projectTitle,
}) async {
  if (instances.isEmpty) return null;
  if (instances.length == 1) return instances.first;
  final luma = context.luma;
  return showModalBottomSheet<McInstance>(
    context: context,
    backgroundColor: luma.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (projectTitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  projectTitle,
                  style: TextStyle(color: luma.textMuted, fontSize: 13),
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: instances.length,
                itemBuilder: (context, i) {
                  final instance = instances[i];
                  return ListTile(
                    onTap: () => Navigator.pop(context, instance),
                    shape: RoundedRectangleBorder(
                      borderRadius: context.lumaDecor.cardBorderRadius,
                    ),
                    leading: Icon(Icons.videogame_asset_rounded, color: luma.accent),
                    title: Text(
                      instance.name,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${instance.versionId} · ${prettyTag(instance.loader)}',
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: luma.textMuted),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
