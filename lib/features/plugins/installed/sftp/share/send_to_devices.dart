import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../p2p/peer_sync_scope.dart';
import '../../../../../theme/luma_theme.dart';
import 'device_share_repository.dart';
import 'device_share_scope.dart';
import 'share_index.dart';

/// One thing a feature wants to hand to the user's other devices.
///
/// The path is resolved lazily because the caller often doesn't have one yet:
/// the gallery holds MediaStore ids on Android and only learns the file behind
/// one when it asks, which is far too slow to do for a whole album up front.
class SendCandidate {
  const SendCandidate({required this.name, required this.resolvePath});

  final String name;
  final Future<String?> Function() resolvePath;

  /// A candidate that already knows its file.
  factory SendCandidate.file(File file) => SendCandidate(
        name: file.uri.pathSegments.isEmpty
            ? file.path
            : file.uri.pathSegments.last,
        resolvePath: () async => file.path,
      );
}

/// Opens the "send to my devices" sheet for [items].
///
/// This is the one entry point any feature should use to push files at the
/// user's other devices. It copies them into the shared folder, which is all
/// sending is — the mirror in [DeviceShareRepository] carries them the rest of
/// the way, straight over the LAN, without a luma server ever seeing a byte.
Future<void> showSendToDevices(
  BuildContext context, {
  required List<SendCandidate> items,
  String? suggestedFolder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.luma.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) => _SendSheet(
      items: items,
      suggestedFolder: suggestedFolder,
    ),
  );
}

class _SendSheet extends StatefulWidget {
  const _SendSheet({required this.items, this.suggestedFolder});

  final List<SendCandidate> items;
  final String? suggestedFolder;

  @override
  State<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<_SendSheet> {
  late final TextEditingController _folder =
      TextEditingController(text: widget.suggestedFolder ?? '');

  bool _sending = false;
  int _done = 0;
  String? _error;

  @override
  void dispose() {
    _folder.dispose();
    super.dispose();
  }

  Future<void> _send(DeviceShareRepository repository) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _sending = true;
      _done = 0;
      _error = null;
    });

    final files = <File>[];
    final missing = <String>[];
    for (final item in widget.items) {
      final path = await item.resolvePath();
      if (path == null) {
        missing.add(item.name);
        continue;
      }
      files.add(File(path));
    }

    if (files.isEmpty) {
      setState(() {
        _sending = false;
        _error = 'None of those could be read from this device.';
      });
      return;
    }

    final subdirectory = normalizeSharePath(_folder.text.trim());
    await repository.addFiles(
      files,
      subdirectory: subdirectory,
      onProgress: (done, _) {
        if (mounted) setState(() => _done = done);
      },
    );

    if (!mounted) return;
    navigator.pop();

    final connected = repository.connectedCount;
    final count = files.length;
    final noun = count == 1 ? 'file' : 'files';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          connected > 0
              ? '$count $noun on the way to your other '
                  '${connected == 1 ? 'device' : 'devices'}.'
              : '$count $noun ready — they will go over as soon as another '
                  'device is on this network.',
        ),
      ),
    );
    if (missing.isNotEmpty) {
      debugPrint('send to devices: could not resolve ${missing.join(', ')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = DeviceShareScope.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.devices_rounded, size: 18, color: luma.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send to your devices',
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.items.length == 1
                              ? widget.items.first.name
                              : '${widget.items.length} items',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (repository == null)
              const _Unavailable()
            else ...[
              _Devices(repository: repository),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: TextField(
                  controller: _folder,
                  enabled: !_sending,
                  decoration: InputDecoration(
                    labelText: 'Folder in the shared folder',
                    hintText: 'Leave empty to drop them at the top',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Text(
                    _error!,
                    style: TextStyle(color: luma.danger, fontSize: 12),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: LumaPrimaryButton(
                  label: _sending
                      ? 'Copying $_done of ${widget.items.length}…'
                      : 'Send',
                  icon: Icons.send_rounded,
                  onTap: _sending ? null : () => _send(repository),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The devices this will reach, so "send" is never a leap of faith.
class _Devices extends StatelessWidget {
  const _Devices({required this.repository});

  final DeviceShareRepository repository;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final peerSync = PeerSyncScope.of(context);

    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final peers = repository.peers;
        if (peers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Text(
              peerSync.isRunning
                  ? 'No other device on this network right now. What you send '
                      'waits in the shared folder and goes over the moment one '
                      'turns up.'
                  : 'Device sync is off. Turn it on in Settings → Sync & '
                      'account and your other devices will pick these up.',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final peer in peers)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: peer.connected ? luma.accentSubtle : luma.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: peer.connected ? luma.accent : luma.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color:
                              peer.connected ? luma.success : luma.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        peer.deviceName,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        peer.connected ? 'here' : 'away',
                        style: TextStyle(color: luma.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Text(
        'The shared folder is not running on this device. It comes with Nova '
        'and needs device sync switched on under Settings → Sync & account, '
        'on this device and the one you want to send to.',
        style: TextStyle(color: luma.textSecondary, fontSize: 12.5, height: 1.5),
      ),
    );
  }
}
