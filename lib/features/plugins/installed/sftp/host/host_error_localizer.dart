import '../../../../../l10n/current_l.dart';

/// Resolves app-owned SFTP wire errors with the receiving device locale.
/// Unknown codes retain the legacy human-readable payload for older peers.
String localizeHostWireError(
  Map<String, dynamic> message, {
  String fallback = '',
}) {
  final code = message['ec'];
  final args = message['ea'];
  final values = args is Map ? args : const <String, dynamic>{};
  final detail = values['detail']?.toString() ?? '';
  switch (code) {
    case 'unsupported_request':
    case 'no_path':
    case 'invalid_path':
      return currentL.sftpHostRefusedRequest;
    case 'operation_failed':
      return currentL.sftpHostCouldNotConnect(detail);
    case 'folder_missing':
      return currentL.sftpHostFolderGone;
    case 'storage_access':
      return currentL.sftpHostStorageAccessBody;
    case 'item_unreadable':
      return currentL.sftpHostItemUnreadable;
    case 'windows_permissions':
      return currentL.sftpHostWindowsPermissionsUnsupported;
    case 'invalid_permissions':
      return currentL.sftpPermissionsInvalid;
    case 'permissions_failed':
    case 'save_failed':
      return currentL.sftpHostSaveFailed(detail);
    case 'transfer_stopped':
      return currentL.sftpHostTransferStopped;
    case 'read_only':
      return currentL.sftpHostAccessReadOnlyHint;
    case 'pairing_lockout':
      return currentL.sftpHostTooManyPairingFailures;
    case 'client_limit':
      final raw = values['maxClients'];
      final maxClients = raw is num ? raw.toInt() : 8;
      return currentL.sftpHostTooManyDevices(maxClients);
    case 'admission_denied':
      return currentL.sftpHostNotLetIn;
    case 'connection_closed':
      return currentL.sftpHostConnectionWasClosed;
    default:
      final legacy = message['e']?.toString();
      if (legacy != null && legacy.isNotEmpty) return legacy;
      return fallback.isEmpty ? currentL.sftpHostRefusedConnection : fallback;
  }
}
