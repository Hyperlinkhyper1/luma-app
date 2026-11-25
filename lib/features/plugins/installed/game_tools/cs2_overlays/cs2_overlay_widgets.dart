import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';

/// One overlay on the Overlays page: an icon, a name with its on/off state,
/// a line on what it does, the start/stop control, then its own body.
class Cs2OverlayCard extends StatelessWidget {
  const Cs2OverlayCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.running,
    required this.action,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool running;
  final Widget action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final phone = context.isPhoneWidth;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LumaIconBadge(icon: icon, color: luma.accent, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Cs2StatusPill(running: running),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (!phone) ...[const SizedBox(width: 16), action],
      ],
    );
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          if (phone) ...[const SizedBox(height: 12), action],
          ...children,
        ],
      ),
    );
  }
}

class Cs2StatusPill extends StatelessWidget {
  const Cs2StatusPill({super.key, required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final color = running ? luma.success : luma.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            running ? t.cs2OverlayRunning : t.cs2OverlayOff,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet fold-out inside a card, for the settings and logs most people
/// never need to open.
class Cs2Disclosure extends StatefulWidget {
  const Cs2Disclosure({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<Cs2Disclosure> createState() => _Cs2DisclosureState();
}

class _Cs2DisclosureState extends State<Cs2Disclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _open ? 0 : -0.25,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: luma.textMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// A check or info icon beside a short line of status text.
class Cs2StatusLine extends StatelessWidget {
  const Cs2StatusLine({
    super.key,
    required this.ok,
    required this.text,
    this.trailing,
  });

  final bool ok;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 16,
          color: ok ? luma.success : luma.warning,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

InputDecoration cs2FieldDecoration(String label, LumaPalette luma) =>
    InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: luma.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: luma.border),
      ),
    );
