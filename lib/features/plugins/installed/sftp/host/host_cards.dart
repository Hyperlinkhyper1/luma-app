/// The pieces both hosting screens are built from — the Host tab
/// (`SftpHostPanel`) and the screen-scoped "This device" page
/// (`SftpThisDevicePage`). The two differ in when hosting starts and stops,
/// not in what a credential or a connected device looks like.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../sftp_paths.dart';
import 'host_server.dart';

/// One labelled value with a copy button: address, port, pairing password.
class HostCopyRow extends StatelessWidget {
  const HostCopyRow({
    super.key,
    required this.label,
    required this.value,
    required this.onCopy,
    this.monospace = false,
    this.enabled = true,
    this.trailing,
  });

  final String label;
  final String value;
  final Future<void> Function()? onCopy;
  final bool monospace;

  /// False greys the value out — for a placeholder like "No network
  /// connection" that is not a credential to read off the screen.
  final bool enabled;

  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        SizedBox(
          width: 128,
          child: Text(
            label,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 42,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: luma.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.border),
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: enabled ? luma.textPrimary : luma.textMuted,
                fontSize: monospace ? 14 : 13,
                fontWeight: monospace ? FontWeight.w700 : FontWeight.w500,
                fontFamily: monospace ? 'monospace' : null,
                letterSpacing: monospace ? 0.6 : null,
              ),
            ),
          ),
        ),
        ?trailing,
        IconButton(
          onPressed: onCopy == null ? null : () => unawaited(onCopy!()),
          iconSize: 18,
          tooltip: 'Copy',
          icon: Icon(Icons.copy_rounded, color: luma.textSecondary),
        ),
      ],
    );
  }
}

/// The prompt shown when a device has the password but still needs a yes.
class HostApprovalCard extends StatelessWidget {
  const HostApprovalCard({
    super.key,
    required this.client,
    required this.onAllow,
    required this.onRefuse,
  });

  final HostClient client;
  final VoidCallback onAllow;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                size: 18,
                color: luma.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${client.deviceName} wants to connect',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'It is at ${client.address} and gave the right pairing password.',
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              LumaPrimaryButton(
                label: 'Allow',
                icon: Icons.check_rounded,
                onTap: onAllow,
              ),
              const SizedBox(width: 8),
              LumaGhostButton(
                label: 'Refuse',
                icon: Icons.close_rounded,
                onTap: onRefuse,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Who is attached right now, and the way to throw one off.
class HostClientsCard extends StatelessWidget {
  const HostClientsCard({
    super.key,
    required this.server,
    required this.emptyMessage,
  });

  final SftpHostServer server;

  /// What to say when nothing is attached. The two screens promise different
  /// things about how long the share lasts, so each supplies its own.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final clients = server.clients.where((c) => !c.awaitingApproval).toList();
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clients.isEmpty
                ? 'No devices connected'
                : '${clients.length} device'
                    '${clients.length == 1 ? '' : 's'} connected',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (clients.isEmpty)
            Text(
              emptyMessage,
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            )
          else
            for (final client in clients) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.devices_rounded,
                      size: 18,
                      color: luma.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.deviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${client.address} · '
                            'sent ${formatFileSize(client.bytesSent)} · '
                            'received ${formatFileSize(client.bytesReceived)}',
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    LumaGhostButton(
                      label: 'Disconnect',
                      icon: Icons.link_off_rounded,
                      onTap: () =>
                          unawaited(server.disconnectClient(client.id)),
                    ),
                  ],
                ),
              ),
            ],
        ],
      ),
    );
  }
}
