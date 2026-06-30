import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/luma_theme.dart';

/// Formats a byte count into a short human-readable string.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Shared shell for a single converter tool: a back-to-hub header with an icon,
/// title and subtitle, then the tool's body in a centered, max-width column.
class ToolScaffold extends StatelessWidget {
  const ToolScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _BackButton(onTap: onBack),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: luma.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style:
                              TextStyle(color: luma.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : luma.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: luma.border),
          ),
          child: Icon(Icons.arrow_back_rounded,
              color: luma.textSecondary, size: 20),
        ),
      ),
    );
  }
}

/// Reusable surface container with luma's card styling.
class ConverterCard extends StatelessWidget {
  const ConverterCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: luma.border),
      ),
      child: child,
    );
  }
}

/// Large dashed-feel "click to choose a file" target.
class ConverterDropZone extends StatefulWidget {
  const ConverterDropZone({
    super.key,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  State<ConverterDropZone> createState() => _ConverterDropZoneState();
}

class _ConverterDropZoneState extends State<ConverterDropZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 220,
          decoration: BoxDecoration(
            color: _hovering ? luma.surfaceHover : luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovering ? luma.accent : luma.border,
              width: _hovering ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.icon, color: luma.accent, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: TextStyle(color: luma.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card showing the chosen file: optional thumbnail, name, meta line and a
/// "Change" action.
class ConverterFileCard extends StatelessWidget {
  const ConverterFileCard({
    super.key,
    required this.name,
    required this.meta,
    required this.onChange,
    this.thumbnail,
    this.icon,
    this.badge,
  });

  final String name;
  final String meta;
  final VoidCallback onChange;

  /// Image preview bytes (used by the image tools).
  final Uint8List? thumbnail;

  /// Fallback icon when there is no thumbnail (audio/video).
  final IconData? icon;

  /// Optional leading badge widget shown before [meta] (e.g. a format chip).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return ConverterCard(
      child: Row(
        children: [
          if (thumbnail != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                thumbnail!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon ?? Icons.insert_drive_file_outlined,
                  color: luma.accent, size: 26),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (badge != null) ...[badge!, const SizedBox(width: 8)],
                    Text(
                      meta,
                      style: TextStyle(color: luma.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ConverterTextButton(label: 'Change', onTap: onChange),
        ],
      ),
    );
  }
}

/// Small uppercase chip used for format labels (PNG, OGG, M4A ...).
class FormatChip extends StatelessWidget {
  const FormatChip({
    super.key,
    required this.label,
    this.big = false,
    this.highlight = false,
  });

  final String label;
  final bool big;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final Color bg = highlight ? luma.accentSubtle : luma.surfaceHover;
    final Color fg = highlight ? luma.accent : luma.textSecondary;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: big ? 16 : 8,
        vertical: big ? 8 : 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: highlight ? Border.all(color: luma.accent) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: big ? 14 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// `SOURCE → TARGET` row of two big format chips.
class FormatTransition extends StatelessWidget {
  const FormatTransition({
    super.key,
    required this.source,
    required this.target,
  });
  final String source;
  final String target;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FormatChip(label: source, big: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Icon(Icons.arrow_forward_rounded,
              color: luma.textSecondary, size: 20),
        ),
        FormatChip(label: target, big: true, highlight: true),
      ],
    );
  }
}

/// Inline text button rendered in the accent color.
class ConverterTextButton extends StatelessWidget {
  const ConverterTextButton({
    super.key,
    required this.label,
    required this.onTap,
  });
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: luma.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width primary action with hover + loading states.
class ConverterPrimaryButton extends StatefulWidget {
  const ConverterPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  State<ConverterPrimaryButton> createState() => _ConverterPrimaryButtonState();
}

class _ConverterPrimaryButtonState extends State<ConverterPrimaryButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final enabled = widget.onTap != null && !widget.loading;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          decoration: BoxDecoration(
            color: !enabled
                ? luma.accent.withValues(alpha: 0.4)
                : (_hovering ? luma.accentHover : luma.accent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: widget.loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(luma.onAccent),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: luma.onAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: luma.onAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Colored info/success/error banner.
class ConverterBanner extends StatelessWidget {
  const ConverterBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.message,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String message;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
