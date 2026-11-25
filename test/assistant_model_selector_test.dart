import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/ai_key_store.dart';
import 'package:luma/features/chat/widgets/assistant_model_selector.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/sync/sync_scope.dart';
import 'package:luma/sync/sync_service.dart';
import 'package:luma/theme/luma_theme.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Keys implements AiKeyStore {
  final connected = <String>{};

  @override
  Future<String?> readKey(String providerId) async =>
      connected.contains(providerId) ? 'test-key' : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sync implements SyncService {
  @override
  bool get serverReady => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Paths extends PathProviderPlatform {
  _Paths(this.directory);

  final Directory? directory;

  @override
  Future<String> getApplicationSupportPath() async =>
      directory?.path ?? (throw UnsupportedError('No support directory'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousPaths = PathProviderPlatform.instance;
  setUp(() => PathProviderPlatform.instance = _Paths(null));
  tearDown(() => PathProviderPlatform.instance = previousPaths);

  testWidgets('API key section shows only the add action without keys', (
    tester,
  ) async {
    final settings = await SettingsController.load();
    addTearDown(settings.dispose);
    settings.setAiModel('openai', 'previous-model');
    await tester.pumpWidget(_app(settings, _Keys()));

    await _openPicker(tester);

    expect(find.text('API key'), findsOneWidget);
    expect(find.byTooltip('Add API key'), findsOneWidget);
    expect(find.text('Manage API keys'), findsNothing);
    expect(find.text('Anthropic Claude'), findsNothing);
    expect(find.text('OpenAI'), findsNothing);
    expect(find.text('OpenRouter'), findsNothing);
    expect(find.text('Google Gemini'), findsNothing);
    expect(find.text('previous-model'), findsNothing);
  });

  testWidgets('add and switch models from a connected provider on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = await SettingsController.load();
    addTearDown(settings.dispose);
    final keys = _Keys()..connected.add('openrouter');
    await tester.pumpWidget(_app(settings, keys));

    Future<void> addModel(String model) async {
      await _openPicker(tester);
      await tester.tap(find.byTooltip('Add model'));
      await tester.pumpAndSettle();
      expect(find.text('OpenRouter'), findsOneWidget);
      expect(find.text('OpenAI'), findsNothing);
      expect(find.text('Manage API keys'), findsOneWidget);
      await tester.enterText(find.byType(TextField), model);
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
    }

    await addModel(' provider/one ');
    await addModel('provider/two');
    expect(settings.aiProviderId, 'openrouter');
    expect(settings.aiModelFor('openrouter'), 'provider/two');

    await _openPicker(tester);
    await tester.tap(find.text('provider/one'));
    await tester.pumpAndSettle();
    expect(settings.aiModelFor('openrouter'), 'provider/one');

    keys.connected.clear();
    settings.setAiProviderId('google');
    await tester.pumpAndSettle();
    await _openPicker(tester);
    expect(find.text('provider/one'), findsNothing);
    expect(find.text('provider/two'), findsNothing);
    expect(find.byTooltip('Add API key'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('saved models persist locally with the legacy selection', () async {
    final directory = await Directory.systemTemp.createTemp('luma-ai-models-');
    final file = File('${directory.path}/luma_settings.json');
    PathProviderPlatform.instance = _Paths(directory);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
      await directory.delete();
    });
    await file.writeAsString(
      '{"aiProviderId":"openai","aiModels":{"openai":"legacy-model"}}',
    );
    final settings = await SettingsController.load();
    addTearDown(settings.dispose);

    expect(settings.savedAiModelsFor('openai'), ['legacy-model']);
    settings.selectAiModel('openai', ' second-model ');
    settings.selectAiModel('openai', 'legacy-model');
    settings.selectAiModel('openai', 'second-model');
    settings.selectAiModel('openai', '   ');
    final snapshot = settings.exportData();
    expect(snapshot.keys, isNot(contains(anyOf('aiModels', 'savedAiModels'))));
    await settings.importData(snapshot);

    final reloaded = await SettingsController.load();
    addTearDown(reloaded.dispose);
    expect(reloaded.aiProviderId, 'openai');
    expect(reloaded.aiModelFor('openai'), 'second-model');
    expect(reloaded.savedAiModelsFor('openai'), [
      'legacy-model',
      'second-model',
    ]);
  });
}

Widget _app(SettingsController settings, AiKeyStore keys) => SyncScope(
  service: _Sync(),
  child: MaterialApp(
    theme: LumaTheme.dark,
    locale: const Locale('en'),
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomRight,
        child: AssistantModelSelector(settings: settings, keyStore: keys),
      ),
    ),
  ),
);

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byType(AssistantModelSelector));
  await tester.pumpAndSettle();
}
