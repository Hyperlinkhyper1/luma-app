import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/app/widgets.dart';
import 'package:luma/features/plugins/installed/account_overview/account_overview_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/account_overview_scope.dart';
import 'package:luma/features/plugins/installed/account_overview/account_overview_shell.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_content_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_content_scope.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_credentials.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_history.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_models.dart';
import 'package:luma/features/plugins/installed/account_overview/youtube_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/youtube_scope.dart';
import 'package:luma/theme/luma_theme.dart';

/// The plugin under every scope, the way `main.dart` nests them — the shell
/// reads every service's state to build its rail, so YouTube's scope is part
/// of the harness even though this file's tests never open its sections.
Widget _app(
  AccountOverviewRepository github,
  McContentRepository mc,
  YoutubeRepository youtube,
) =>
    MaterialApp(
      theme: LumaTheme.dark,
      home: AccountOverviewScope(
        repository: github,
        child: McContentScope(
          repository: mc,
          child: YoutubeScope(
            repository: youtube,
            child: const Scaffold(body: AccountOverviewPage()),
          ),
        ),
      ),
    );

McProject _project(
  McPlatform platform,
  String name, {
  int downloads = 0,
  int followers = 0,
  int views = 0,
  bool approximate = false,
}) =>
    McProject(
      platform: platform,
      id: '$name-id',
      slug: name.toLowerCase(),
      name: name,
      url: 'https://example.invalid/$name',
      kind: 'mod',
      downloads: downloads,
      followers: followers,
      views: views,
      approximate: approximate,
    );

/// A snapshot with all three platforms reporting.
McSnapshot _populated() => McSnapshot.empty
    .withResult(McPlatformResult(
      platform: McPlatform.curseforge,
      state: McPlatformState.ok,
      creator: const McCreator(platform: McPlatform.curseforge, handle: '77'),
      projects: [_project(McPlatform.curseforge, 'Alloy', downloads: 120000)],
      fetchedAt: DateTime(2026, 9, 1),
    ))
    .withResult(McPlatformResult(
      platform: McPlatform.modrinth,
      state: McPlatformState.ok,
      creator: const McCreator(platform: McPlatform.modrinth, handle: 'octo'),
      projects: [
        _project(McPlatform.modrinth, 'Sodium', downloads: 30000, followers: 40),
      ],
      fetchedAt: DateTime(2026, 9, 1),
    ))
    .withResult(McPlatformResult(
      platform: McPlatform.planetMinecraft,
      state: McPlatformState.ok,
      creator: const McCreator(
        platform: McPlatform.planetMinecraft,
        handle: 'octo',
      ),
      projects: [
        _project(
          McPlatform.planetMinecraft,
          'Castle',
          views: 1100,
          followers: 166,
          approximate: true,
        ),
      ],
      fetchedAt: DateTime(2026, 9, 1),
    ))
    .withFetchedAt(DateTime(2026, 9, 1));

/// Two weeks of history, so the trend charts have something to draw.
McHistoryStore _history() {
  final store = McHistoryStore.inMemory();
  for (var i = 0; i < 14; i++) {
    final day = DateTime.now().subtract(Duration(days: 13 - i));
    store.record('curseforge', downloads: 100000 + i * 1500, at: day);
    store.record('modrinth', downloads: 25000 + i * 400, at: day);
    store.record('pmc', downloads: 0, views: 900 + i * 15, at: day);
  }
  return store;
}

const _configured = McCredentials(
  modrinthUsername: 'octo',
  curseforgeApiKey: 'k',
  curseforgeAuthorId: '77',
  // No PMC username on purpose: the one-pixel WebView must not be mounted in
  // tests, where no browser engine exists to back it.
);

/// A surface tall enough that the MC Content page lays out in full.
///
/// Its views are `ListView`s, which only build what fits — asserting on a
/// panel below the fold would fail for want of a scroll rather than for want
/// of the panel.
const _tall = Size(1400, 2400);

/// Pumps the plugin with both repositories' startup reads already finished.
///
/// Both touch real disk I/O through path_provider, which the widget tester's
/// fake clock will not drive — and an unloaded GitHub repository leaves a
/// spinner spinning, so `pumpAndSettle` would never return.
Future<void> _pump(
  WidgetTester tester,
  AccountOverviewRepository github,
  McContentRepository mc, {
  Size size = _tall,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.runAsync(() => github.load());
  await tester.runAsync(() => mc.load());
  await tester.runAsync(() => _youtube.load());
  await tester.pumpWidget(_app(github, mc, _youtube));
  await tester.pumpAndSettle();
}

late YoutubeRepository _youtube;

Future<void> _openMcContent(WidgetTester tester) async {
  // The rail is an accordion — only the currently-selected service's
  // sections are in the tree — so Minecraft's heading needs a tap first
  // whenever GitHub (the default selection) is the one currently expanded.
  // Below 640px the rail also collapses to icons on its own, so the heading
  // has no label to tap there either — its icon still works.
  if (find.text(AccountSection.mcContent.label).evaluate().isEmpty &&
      find.byIcon(AccountSection.mcContent.icon).evaluate().isEmpty) {
    final headingByLabel = find.text(AccountService.minecraft.label);
    await tester.tap(
      headingByLabel.evaluate().isEmpty
          ? find.byIcon(AccountService.minecraft.icon).first
          : headingByLabel.first,
    );
    await tester.pumpAndSettle();
  }
  final byLabel = find.text(AccountSection.mcContent.label);
  await tester.tap(
    byLabel.evaluate().isEmpty
        ? find.byIcon(AccountSection.mcContent.icon).first
        : byLabel.first,
  );
  await tester.pumpAndSettle();
}

/// Taps one of MC Content's inner views.
///
/// Scoped to the segmented strip rather than matched by text alone: "Overview"
/// also names a GitHub section in the rail, and "Projects" also labels a stat
/// tile, so a bare text finder would be ambiguous or hit the wrong one.
Future<void> _openView(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(LumaSegmentedTabs),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AccountOverviewRepository github;
  late McContentRepository mc;

  setUp(() {
    github = AccountOverviewRepository();
    mc = McContentRepository();
    _youtube = YoutubeRepository();
  });
  tearDown(() {
    github.dispose();
    mc.dispose();
    _youtube.dispose();
  });

  testWidgets('the sidebar groups GitHub and Minecraft separately',
      (tester) async {
    await _pump(tester, github, mc);

    for (final service in AccountService.values) {
      expect(find.text(service.label), findsWidgets,
          reason: '${service.label} should head its own group');
    }
    // The rail is an accordion, so Minecraft's own section only shows once
    // its heading is opened — GitHub's group is the one expanded by default.
    await tester.tap(find.text(AccountService.minecraft.label));
    await tester.pumpAndSettle();
    expect(find.text('MC Content'), findsWidgets);
  });

  testWidgets('MC Content is reachable without a GitHub token',
      (tester) async {
    await _pump(tester, github, mc);

    // GitHub is not connected here; the Minecraft entry must still open, or
    // its setup screen would be unreachable.
    await _openMcContent(tester);

    expect(find.text('Track your Minecraft content'), findsOneWidget);
    expect(find.text('Set up platforms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the setup prompt states what each platform needs',
      (tester) async {
    await _pump(tester, github, mc);
    await _openMcContent(tester);

    expect(find.textContaining('Modrinth — username only'), findsOneWidget);
    expect(find.textContaining('CurseForge — API key required'), findsOneWidget);
    expect(
      find.textContaining('Planet Minecraft — username only'),
      findsOneWidget,
    );
  });

  group('configured', () {
    setUp(() {
      mc.seedForTest(
        _populated(),
        credentials: _configured,
        history: _history(),
      );
    });

    testWidgets('combines CurseForge and Modrinth but not PMC',
        (tester) async {
      await _pump(tester, github, mc);
      await _openMcContent(tester);

      // 120,000 + 30,000 = 150k, and PMC's numbers stay out of it.
      expect(find.text('Total downloads'), findsOneWidget);
      expect(find.text('150k'), findsWidgets);
      expect(find.text('Combined library'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Planet Minecraft sits under its own header', (tester) async {
      await _pump(tester, github, mc);
      await _openMcContent(tester);

      expect(find.text('Planet Minecraft'), findsWidgets);
      expect(find.text('Diamonds'), findsOneWidget);
      // The rounding caveat belongs next to the rounded numbers, not buried
      // in a tooltip.
      expect(find.textContaining('approximate'), findsWidgets);
    });

    testWidgets('the projects view lists every platform', (tester) async {
      await _pump(tester, github, mc);
      await _openMcContent(tester);
      await _openView(tester, 'Projects');

      expect(find.text('Alloy'), findsOneWidget);
      expect(find.text('Sodium'), findsOneWidget);
      expect(find.text('Castle'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filtering the projects view by platform narrows it',
        (tester) async {
      await _pump(tester, github, mc);
      await _openMcContent(tester);
      await _openView(tester, 'Projects');

      // The platform strip is the second segmented row inside this view.
      await tester.tap(
        find
            .descendant(
              of: find.byType(LumaSegmentedTabs),
              matching: find.text('Modrinth'),
            )
            .last,
      );
      await tester.pumpAndSettle();

      expect(find.text('Sodium'), findsOneWidget);
      expect(find.text('Alloy'), findsNothing);
      expect(find.text('Castle'), findsNothing);
    });

    testWidgets('the trends view renders its charts', (tester) async {
      await _pump(tester, github, mc);
      await _openMcContent(tester);
      await _openView(tester, 'Trends');

      expect(find.text('Downloads gained per day'), findsOneWidget);
      // With 14 days recorded there is real data, so no chart should be
      // showing the "collecting" placeholder.
      expect(find.text('No history yet'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every inner view renders without an exception',
        (tester) async {
      await _pump(tester, github, mc);
      await _openMcContent(tester);

      for (final view in ['Overview', 'Projects', 'Trends']) {
        await _openView(tester, view);
        expect(tester.takeException(), isNull, reason: '$view should render');
      }
    });

    testWidgets('renders at phone width without overflowing', (tester) async {
      await _pump(tester, github, mc, size: const Size(375, 812));
      await _openMcContent(tester);

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a platform that failed explains itself', (tester) async {
    mc.seedForTest(
      McSnapshot.empty.withResult(const McPlatformResult(
        platform: McPlatform.curseforge,
        state: McPlatformState.failed,
        message: 'CurseForge rejected the API key.',
      )),
      credentials: _configured,
    );
    await _pump(tester, github, mc);
    await _openMcContent(tester);

    expect(find.text('CurseForge rejected the API key.'), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);
  });

  testWidgets('a chart with no history says so instead of drawing an empty axis',
      (tester) async {
    mc.seedForTest(
      _populated(),
      credentials: _configured,
      history: McHistoryStore.inMemory(),
    );
    await _pump(tester, github, mc);
    await _openMcContent(tester);

    // CurseForge and Planet Minecraft publish no history at all, so a fresh
    // install genuinely has nothing to draw and must say so.
    expect(find.text('No history yet'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
