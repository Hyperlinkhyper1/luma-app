import 'dart:io';

/// Closes the server's data directory (0700) and its secret key (0600) to
/// every other account on the host. Both used to keep the umask's modes, so
/// any local user or service could read `secret.key` and walk the blobs and
/// stores beside it. Best effort: a failure is logged rather than fatal, so
/// an unusual mount never keeps the server from starting. POSIX only; on
/// Windows the account directory gets its own ACL in
/// [restrictAccountDirectory].
Future<void> restrictDataDirectory(Directory root) =>
    _chmodQuietly('700', root.absolute.path);

/// See [restrictDataDirectory].
Future<void> restrictPrivateFile(File file) =>
    _chmodQuietly('600', file.absolute.path);

Future<void> _chmodQuietly(String mode, String path) async {
  if (Platform.isWindows) return;
  try {
    final result = await Process.run('/bin/chmod', [mode, path]);
    if (result.exitCode == 0) return;
    stderr.writeln('[luma] could not chmod $mode $path: ${result.stderr}');
  } on ProcessException catch (e) {
    stderr.writeln('[luma] could not chmod $mode $path: $e');
  }
}

/// Restricts the dedicated account directory to the server's OS identity.
/// Host administrators can still take ownership; this is not a root sandbox.
Future<void> restrictAccountDirectory(Directory directory) async {
  final type = await FileSystemEntity.type(directory.path, followLinks: false);
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.directory) {
    throw StateError('Account storage must be a real directory, not a link.');
  }
  await directory.create(recursive: true);
  if (Platform.isWindows) {
    final systemRoot = Platform.environment['SystemRoot'];
    if (systemRoot == null)
      throw StateError('Windows system directory unavailable.');
    final result = await Process.run(
        '$systemRoot/System32/WindowsPowerShell/v1.0/powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'''
$ErrorActionPreference = 'Stop'
$owner = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = New-Object System.Security.AccessControl.DirectorySecurity
$acl.SetOwner($owner)
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($owner, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.AddAccessRule($rule)
(New-Object System.IO.DirectoryInfo($env:LUMA_ACCOUNT_DIRECTORY)).SetAccessControl($acl)
''',
    ],
        environment: {
          'LUMA_ACCOUNT_DIRECTORY': directory.absolute.path
        });
    if (result.exitCode != 0)
      throw StateError('Cannot restrict account directory permissions.');
  } else {
    final result =
        await Process.run('/bin/chmod', ['700', directory.absolute.path]);
    if (result.exitCode != 0)
      throw StateError('Cannot restrict account directory permissions.');
  }
}
