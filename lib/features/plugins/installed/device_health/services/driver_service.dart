import 'package:url_launcher/url_launcher.dart';

/// Drivers get no auto-install and no invented "N updates pending" claim —
/// Windows exposes no generic driver-update API, so this only ever hands off
/// to a tool that actually knows: the GPU vendor's own updater, or Windows
/// Update's own driver-update surface.
class DriverService {
  const DriverService();

  static const _vendorUrls = {
    'NVIDIA': 'https://www.nvidia.com/Download/index.aspx',
    'AMD': 'https://www.amd.com/en/support',
    'Intel': 'https://www.intel.com/content/www/us/en/support/detect.html',
  };

  /// The best driver-update destination for [gpuVendor] (as reported by
  /// [GpuInfo.vendor]) — the vendor's own downloads page, or Windows Update
  /// for anything luma can't identify a vendor tool for.
  String urlFor(String gpuVendor) => _vendorUrls[gpuVendor] ?? _windowsUpdateUri;

  static const _windowsUpdateUri = 'ms-settings:windowsupdate';

  Future<bool> openFor(String gpuVendor) => launchUrl(Uri.parse(urlFor(gpuVendor)));

  Future<bool> openWindowsUpdate() => launchUrl(Uri.parse(_windowsUpdateUri));
}
