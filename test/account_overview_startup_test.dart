import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/account_overview/account_overview_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/account_overview_scope.dart';
import 'package:luma/features/plugins/installed/account_overview/account_overview_shell.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_content_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_content_scope.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/spotify_scope.dart';
import 'package:luma/features/plugins/installed/account_overview/youtube_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/youtube_scope.dart';
import 'package:luma/l10n/app_localizations.dart';
import 'package:luma/theme/luma_theme.dart';

class _StartupYoutubeRepository extends YoutubeRepository {
  Future<void>? startup;

  @override
  Future<void> load() => startup = super.load();
}

void main() {
  testWidgets('YouTube reaches setup when opened without preloading', (
    tester,
  ) async {
    final github = AccountOverviewRepository();
    final minecraft = McContentRepository();
    final youtube = _StartupYoutubeRepository();
    final spotify = SpotifyRepository();
    addTearDown(() {
      github.dispose();
      minecraft.dispose();
      youtube.dispose();
      spotify.dispose();
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LumaTheme.dark,
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: AccountOverviewScope(
            repository: github,
            child: McContentScope(
              repository: minecraft,
              child: YoutubeScope(
                repository: youtube,
                child: SpotifyScope(
                  repository: spotify,
                  child: const Scaffold(body: AccountOverviewPage()),
                ),
              ),
            ),
          ),
        ),
      );
      await youtube.startup;
      await github.load();
      await spotify.load();
    });

    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overview').last);
    await tester.pump();

    expect(
      youtube.loaded,
      isTrue,
      reason: 'Opening Account Overview must start YouTube initialization',
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final context = tester.element(find.byType(AccountOverviewPage));
    expect(
      find.text(L.of(context).accountOverviewConnectYoutubeTitle),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
