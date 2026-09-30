import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/audio_tools/audio_tools_page.dart';
import 'package:luma/features/plugins/installed/audio_tools/audio_tools_repository.dart';
import 'package:luma/features/plugins/installed/audio_tools/audio_tools_scope.dart';
import 'package:luma/features/plugins/installed/audio_tools/audio_types.dart';
import 'package:luma/features/plugins/installed/audio_tools/eq.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';
import 'package:luma/theme/theme_style.dart';

const _mic = AudioDevice(id: 'mic', name: 'Microphone (USB Headset)');
const _speakers = AudioDevice(id: 'spk', name: 'Speakers (Realtek(R) Audio)');
const _cableIn = AudioDevice(
  id: 'cable-in',
  name: 'CABLE Input (VB-Audio Virtual Cable)',
);
const _cableOut = AudioDevice(
  id: 'cable-out',
  name: 'CABLE Output (VB-Audio Virtual Cable)',
);

Widget _wrap(AudioToolsRepository repo) => MaterialApp(
  theme: LumaTheme.from(Brightness.dark, null, LumaThemeStyle.standard),
  localizationsDelegates: L.localizationsDelegates,
  supportedLocales: L.supportedLocales,
  home: Scaffold(
    body: AudioToolsScope(repository: repo, child: const AudioToolsPage()),
  ),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('without a virtual cable it offers the VB-CABLE setup', (
    tester,
  ) async {
    _size(tester, const Size(1400, 1100));
    final repo = AudioToolsRepository(
      devices: const AudioDevices(
        inputs: [_mic],
        outputs: [_speakers],
        defaultInputId: 'mic',
        defaultOutputId: 'spk',
      ),
    );
    await tester.pumpWidget(_wrap(repo));
    expect(tester.takeException(), isNull);
    expect(find.text('Get VB-CABLE'), findsOneWidget);
    expect(find.textContaining('not a virtual cable'), findsOneWidget);

    await tester.ensureVisible(find.text('Deep'));
    await tester.tap(find.text('Deep'));
    await tester.pump(const Duration(seconds: 1));
    expect(repo.activePreset, EqPreset.deep);
  });

  testWidgets('with a cable installed it walks through the Discord steps', (
    tester,
  ) async {
    _size(tester, const Size(1400, 1100));
    final repo = AudioToolsRepository(
      devices: const AudioDevices(
        inputs: [_mic, _cableOut],
        outputs: [_speakers, _cableIn],
        defaultInputId: 'mic',
        defaultOutputId: 'spk',
      ),
    );
    await tester.pumpWidget(_wrap(repo));
    expect(find.text('Use it in Discord'), findsOneWidget);
    expect(find.textContaining(_cableOut.name), findsOneWidget);

    await tester.tap(find.text('Use it'));
    await tester.pump(const Duration(seconds: 1));
    expect(repo.outputId, 'cable-in');
    expect(find.text('Use it'), findsNothing);
    expect(find.textContaining('not a virtual cable'), findsNothing);
  });

  testWidgets('the page fits a phone-width window', (tester) async {
    _size(tester, const Size(360, 780));
    final repo = AudioToolsRepository(
      devices: const AudioDevices(
        inputs: [_mic],
        outputs: [_speakers, _cableIn],
      ),
    );
    await tester.pumpWidget(_wrap(repo));
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging a handle on the graph reshapes that band', (
    tester,
  ) async {
    _size(tester, const Size(1400, 1100));
    final repo = AudioToolsRepository();
    await tester.pumpWidget(_wrap(repo));
    final graph = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.size.height == 240,
    );
    await tester.ensureVisible(graph);
    await tester.pumpAndSettle();
    final rect = tester.getRect(graph);
    // Band 5 sits at 1 kHz, 0 dB: 1 kHz is log(50)/log(1000) of the way
    // across the plot, which starts 34 px in and ends 8 px short.
    final plotWidth = rect.width - 42;
    final start = Offset(
      rect.left + 34 + plotWidth * 0.5663,
      rect.top + 10 + (rect.height - 30) / 2,
    );
    await tester.dragFrom(start, const Offset(0, -60));
    await tester.pump(const Duration(seconds: 1));
    expect(repo.eq.bands[4].gainDb, greaterThan(6));
    expect(repo.activePreset, isNull);
  });
}
