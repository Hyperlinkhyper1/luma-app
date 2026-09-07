import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/update/update_service.dart';

/// Assets as CI now publishes them: one APK per ABI plus the Windows
/// installer. Picking the wrong one is not a cosmetic bug — an x86_64 APK on
/// an ARM phone installs and then fails to start.
const _splitRelease = [
  'luma-1.0.250-arm64-v8a.apk',
  'luma-1.0.250-armeabi-v7a.apk',
  'luma-1.0.250-x86_64.apk',
  'luma-setup.exe',
  'luma-1.0.250-linux-x64.tar.gz',
  'luma-1.0.250-unsigned.ipa',
];

/// What every release up to 1.0.248 contained: a single universal APK.
const _universalRelease = [
  'luma-1.0.248.apk',
  'luma-setup.exe',
  'luma-1.0.248-linux-x64.tar.gz',
];

void main() {
  group('pickAssetName', () {
    test('picks the ABI-matching APK out of a split release', () {
      expect(
        UpdateService.pickAssetName(_splitRelease, abi: Abi.androidArm64),
        'luma-1.0.250-arm64-v8a.apk',
      );
      expect(
        UpdateService.pickAssetName(_splitRelease, abi: Abi.androidArm),
        'luma-1.0.250-armeabi-v7a.apk',
      );
      expect(
        UpdateService.pickAssetName(_splitRelease, abi: Abi.androidX64),
        'luma-1.0.250-x86_64.apk',
      );
    });

    test('a 64-bit ARM phone falls back to the 32-bit APK, not the reverse',
        () {
      const only32 = ['luma-1.0.250-armeabi-v7a.apk'];
      expect(
        UpdateService.pickAssetName(only32, abi: Abi.androidArm64),
        'luma-1.0.250-armeabi-v7a.apk',
      );

      const only64 = ['luma-1.0.250-arm64-v8a.apk'];
      expect(
        UpdateService.pickAssetName(only64, abi: Abi.androidArm),
        isNull,
      );
    });

    test('still updates from an older release that has one universal APK', () {
      expect(
        UpdateService.pickAssetName(_universalRelease, abi: Abi.androidArm64),
        'luma-1.0.248.apk',
      );
      expect(
        UpdateService.pickAssetName(_universalRelease, abi: Abi.androidX64),
        'luma-1.0.248.apk',
      );
    });

    test('never mistakes another ABI\'s APK for a universal one', () {
      const wrongAbiOnly = ['luma-1.0.250-x86_64.apk', 'luma-setup.exe'];
      expect(
        UpdateService.pickAssetName(wrongAbiOnly, abi: Abi.androidArm64),
        isNull,
      );
    });

    test('takes the installer, never an APK, on Windows', () {
      expect(
        UpdateService.pickAssetName(_splitRelease, abi: Abi.windowsX64),
        'luma-setup.exe',
      );
      expect(
        UpdateService.pickAssetName(_universalRelease, abi: Abi.windowsX64),
        'luma-setup.exe',
      );
    });

    test('reports nothing installable when the build is still running', () {
      const notReady = ['luma-1.0.250-linux-x64.tar.gz'];
      expect(
        UpdateService.pickAssetName(notReady, abi: Abi.androidArm64),
        isNull,
      );
      expect(
        UpdateService.pickAssetName(notReady, abi: Abi.windowsX64),
        isNull,
      );
    });
  });
}
