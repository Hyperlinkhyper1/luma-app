import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../command_icons.dart';
import '../command_run.dart';

/// What a host (rojo serve, a dev server, …) looks like from outside: the
/// address it serves on, whether it accepts connections, and who is
/// connected. Rojo is recognised by its info endpoint and gets a Roblox
/// Studio line of its own.
class HostConnectionCard extends StatelessWidget {
  const HostConnectionCard({super.key, required this.run});
  final CommandRun run;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final host = run.host;
    final port = host?.port ?? run.detectedPort;

    final rows = <Widget>[];
    if (!run.isActive) {
      rows.add(_Line(
        icon: Icons.power_settings_new_rounded,
        color: luma.textMuted,
        title: t.cmdDashHostOffline,
      ));
    } else if (port == null) {
      rows.add(_Line(
        icon: Icons.hourglass_top_rounded,
        color: luma.warning,
        title: t.cmdDashWaitingForPort,
      ));
    } else {
      final address = 'localhost:$port';
      rows.add(Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.cmdDashAddress,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  address,
                  style: monoStyle.copyWith(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.cmdDashCopyAddress,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: address));
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(t.cmdDashCopied),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(Icons.copy_rounded, color: luma.textSecondary),
          ),
          if (host?.isRojo != true)
            IconButton(
              tooltip: t.cmdDashOpenInBrowser,
              onPressed: () => launchUrl(Uri.parse('http://localhost:$port')),
              icon: Icon(Icons.open_in_browser_rounded, color: luma.textSecondary),
            ),
        ],
      ));
      rows.add(const SizedBox(height: 12));

      if (host == null) {
        rows.add(_Line(
          icon: Icons.sync_rounded,
          color: luma.textMuted,
          title: t.cmdDashChecking,
        ));
      } else {
        rows.add(_Line(
          icon: host.listening ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: host.listening ? luma.success : luma.warning,
          title: host.listening ? t.cmdDashListening : t.cmdDashNotListening,
        ));
        if (host.isRojo) {
          rows
            ..add(const SizedBox(height: 10))
            ..add(_Line(
              icon: Icons.dns_rounded,
              color: luma.accent,
              title: t.cmdDashRojoServer(host.rojoVersion!),
              subtitle: host.rojoProject,
            ))
            ..add(const SizedBox(height: 10))
            ..add(_Line(
              icon: host.clients.isNotEmpty
                  ? Icons.link_rounded
                  : Icons.link_off_rounded,
              color: host.clients.isNotEmpty ? luma.success : luma.textMuted,
              title: host.clients.isNotEmpty
                  ? t.cmdDashRojoStudioConnected
                  : t.cmdDashRojoStudioNotConnected,
              subtitle: host.clients.isNotEmpty ? null : t.cmdDashRojoStudioHint,
            ));
        }
        rows
          ..add(const SizedBox(height: 10))
          ..add(_Line(
            icon: Icons.devices_rounded,
            color: host.clients.isNotEmpty ? luma.success : luma.textMuted,
            title: t.cmdDashClients(host.clients.length),
            subtitle: host.clients.isEmpty
                ? t.cmdDashNoClients
                : host.clients.take(4).map((c) => c.remoteAddress).join('\n'),
            mono: host.clients.isNotEmpty,
          ));
      }
    }

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cell_tower_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 8),
              Text(
                t.cmdDashConnection,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.mono = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: (mono ? monoStyle : const TextStyle()).copyWith(
                    color: luma.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
