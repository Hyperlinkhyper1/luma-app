import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/chat/ai_key_store.dart';
import 'package:luma/features/chat/assistant_auto_router.dart';
import 'package:luma/features/chat/assistant_compose_mode.dart';
import 'package:luma/features/chat/widgets/assistant_model_selector.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/settings/settings_controller.dart';
import 'package:luma/sync/sync_scope.dart';
import 'package:luma/sync/sync_service.dart';
import 'package:luma/theme/luma_theme.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Keys implements AiKeyStore {
  @override
  Future<String?> readKey(String providerId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sync implements SyncService {
  @override
  bool get serverReady => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoPaths extends PathProviderPlatform {
  @override
  Future<String> getApplicationSupportPath() async =>
      throw UnsupportedError('No support directory');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousPaths = PathProviderPlatform.instance;
  setUp(() => PathProviderPlatform.instance = _NoPaths());
  tearDown(() => PathProviderPlatform.instance = previousPaths);

  testWidgets('Luma Auto is picked from the model menu and names the pill', (
    tester,
  ) async {
    final settings = await SettingsController.load();
    addTearDown(settings.dispose);
    settings.setAiProviderId('openai');
    settings.recordModelUsage(kAutoModelUsageKey);
    await tester.pumpWidget(
      SyncScope(
        service: _Sync(),
        child: MaterialApp(
          theme: LumaTheme.dark,
          locale: const Locale('en'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomRight,
              child: AssistantModelSelector(settings: settings, keyStore: _Keys()),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AssistantModelSelector));
    await tester.pumpAndSettle();
    expect(find.text('Luma Auto'), findsOneWidget);
    expect(find.text('1 msg'), findsOneWidget);
    await tester.tap(find.text('Luma Auto'));
    await tester.pumpAndSettle();

    expect(settings.aiProviderId, 'google');
    expect(settings.aiMode, kAutoAiMode);
    expect(
      find.descendant(
        of: find.byType(AssistantModelSelector),
        matching: find.text('Luma Auto'),
      ),
      findsOneWidget,
    );
    expect(deepResearchAvailable(settings.aiProviderId, settings.aiMode), isTrue);

    await tester.tap(find.byType(AssistantModelSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Luma Nebula').last);
    await tester.pumpAndSettle();
    expect(settings.aiMode, 'smarter');
    expect(tester.takeException(), isNull);
  });
}
