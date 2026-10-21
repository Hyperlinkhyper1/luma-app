import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/game_tools/cs2_translator/cs2_translator_service.dart';

void main() {
  group('Cs2TranslatorOptions.toArgs', () {
    test('defaults match the script and let it place the overlay', () {
      expect(const Cs2TranslatorOptions().toArgs(), [
        '-TargetLang',
        'en',
        '-HideAfterSeconds',
        '20',
        '-MaxLines',
        '8',
        '-OverlayX',
        '20',
        '-OverlayY',
        '-1',
      ]);
    });

    test('passes a log path and the no-overlay switch only when set', () {
      final args = const Cs2TranslatorOptions(
        targetLang: 'nl',
        overlayY: 400,
        logPath: r' D:\Games\csgo\console.log ',
        overlay: false,
      ).toArgs();
      expect(args, containsAllInOrder(['-OverlayY', '400']));
      expect(
        args,
        containsAllInOrder(['-LogPath', r'D:\Games\csgo\console.log']),
      );
      expect(args.last, '-NoOverlay');
    });

    test('clamps out-of-range numbers', () {
      final args = const Cs2TranslatorOptions(
        hideAfterSeconds: 0,
        maxLines: 500,
      ).toArgs();
      expect(args, containsAllInOrder(['-HideAfterSeconds', '1']));
      expect(args, containsAllInOrder(['-MaxLines', '30']));
    });
  });

  test('options survive a JSON round trip, including an automatic Y', () {
    const options = Cs2TranslatorOptions(targetLang: 'fr', maxLines: 5);
    final back = Cs2TranslatorOptions.fromJson(options.toJson());
    expect(back.toArgs(), options.toArgs());
    expect(back.overlayY, isNull);
  });

  test('reads library folders out of libraryfolders.vdf', () {
    const vdf = r'''
"libraryfolders"
{
	"0"
	{
		"path"		"C:\\Program Files (x86)\\Steam"
	}
	"1"
	{
		"path"		"D:\\SteamLibrary"
	}
}''';
    expect(parseSteamLibraryPaths(vdf), [
      r'C:\Program Files (x86)\Steam',
      r'D:\SteamLibrary',
    ]);
  });
}
