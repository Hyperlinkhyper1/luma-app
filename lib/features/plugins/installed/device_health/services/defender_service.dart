import 'package:url_launcher/url_launcher.dart';

import 'powershell_runner.dart';

/// The "virus check" category: a window onto Windows Defender's own status,
/// never a scanner of luma's own. luma reads `Get-MpComputerStatus` and can
/// trigger Defender's own scan (`Start-MpScan`) or open the Windows Security
/// app directly — it never touches a file's bytes itself.
class DefenderService {
  const DefenderService();

  /// Starts a Defender quick scan and returns immediately — a scan can run
  /// for minutes, so this doesn't wait for it to finish. Progress from here
  /// on is visible in Windows Security itself.
  Future<bool> startQuickScan() {
    return PowerShellRunner.startDetached('Start-MpScan -ScanType QuickScan');
  }

  /// Opens the Windows Security app via its registered URI scheme.
  Future<bool> openWindowsSecurity() {
    return launchUrl(Uri.parse('windowsdefender:'));
  }
}
