import 'dart:io';

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
Set-Acl -LiteralPath $env:LUMA_ACCOUNT_DIRECTORY -AclObject $acl
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
