import 'dart:io';

import 'package:luma_sync_server/private_directory.dart';
import 'package:test/test.dart';

void main() {
  test('account directory can be restricted again after a server restart',
      () async {
    final root = await Directory.systemTemp.createTemp('luma_account_acl_');
    addTearDown(() => root.delete(recursive: true));
    final accounts = Directory('${root.path}${Platform.pathSeparator}accounts');

    await restrictAccountDirectory(accounts);
    final record = File('${accounts.path}${Platform.pathSeparator}record');
    await record.writeAsString('retained');
    await restrictAccountDirectory(accounts);

    expect(await record.readAsString(), 'retained');
    if (Platform.isWindows) {
      final systemRoot = Platform.environment['SystemRoot']!;
      final result = await Process.run(
        '$systemRoot/System32/WindowsPowerShell/v1.0/powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'''
$ErrorActionPreference = 'Stop'
$owner = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = (New-Object System.IO.DirectoryInfo($env:LUMA_ACCOUNT_DIRECTORY)).GetAccessControl()
$rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
if (-not $acl.AreAccessRulesProtected -or $rules.Count -ne 1) { exit 1 }
$rule = $rules[0]
if ($acl.GetOwner([System.Security.Principal.SecurityIdentifier]) -ne $owner -or
    $rule.IdentityReference -ne $owner -or $rule.IsInherited -or
    $rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow -or
    $rule.FileSystemRights -ne [System.Security.AccessControl.FileSystemRights]::FullControl -or
    $rule.InheritanceFlags -ne ([System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit)) {
  exit 1
}
''',
        ],
        environment: {'LUMA_ACCOUNT_DIRECTORY': accounts.absolute.path},
      );
      expect(result.exitCode, 0, reason: '${result.stderr}');
    } else {
      final stat = await accounts.stat();
      expect(stat.mode & 0x1ff, 0x1c0);
    }
  });
}
