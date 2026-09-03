import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/account_overview/account_overview_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/account_overview_scope.dart';
import 'package:luma/features/plugins/installed/account_overview/account_overview_shell.dart';
import 'package:luma/features/plugins/installed/account_overview/github_credentials.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_content_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/mc_content_scope.dart';
import 'package:luma/features/plugins/installed/account_overview/github_models.dart';
import 'package:luma/features/plugins/installed/account_overview/youtube_repository.dart';
import 'package:luma/features/plugins/installed/account_overview/youtube_scope.dart';
import 'package:luma/theme/luma_theme.dart';

/// The plugin under its scope, the way `main.dart` nests it.
///
/// There is no path_provider on the host, so the repository's disk reads all
/// fail and it settles into the disconnected state — which is exactly the
/// first-run path worth covering.
Widget _app(
  AccountOverviewRepository repository,
  McContentRepository mc,
  YoutubeRepository youtube, {
  Size? size,
}) =>
    MediaQuery(
      data: MediaQueryData(size: size ?? const Size(1280, 800)),
      child: MaterialApp(
        theme: LumaTheme.dark,
        home: AccountOverviewScope(
          repository: repository,
          // The shell reads every service's state to build its rail, so the
          // other scopes are part of the harness even for GitHub-only tests.
          child: McContentScope(
            repository: mc,
            child: YoutubeScope(
              repository: youtube,
              child: const Scaffold(body: AccountOverviewPage()),
            ),
          ),
        ),
      ),
    );

/// Pumps the plugin with its startup read already finished.
///
/// [AccountOverviewRepository.load] touches real disk I/O through
/// path_provider, which the widget tester's fake clock will not drive — so it
/// runs outside it first, leaving the repository settled and the page's own
/// `load()` call a no-op.
Future<void> _pumpApp(
  WidgetTester tester,
  AccountOverviewRepository repository, {
  Size? size,
}) async {
  await tester.runAsync(() => repository.load());
  await tester.runAsync(() => _mc.load());
  await tester.runAsync(() => _youtube.load());
  await tester.pumpWidget(_app(repository, _mc, _youtube, size: size));
  await tester.pumpAndSettle();
}

late McContentRepository _mc;
late YoutubeRepository _youtube;

/// Pumps a repository that was seeded rather than loaded.
///
/// The Minecraft and YouTube repositories still need their own startup read
/// even for GitHub tests: both are reachable from the rail, and an unloaded
/// one leaves a spinner that `pumpAndSettle` would wait on forever.
Future<void> _pumpSeeded(
  WidgetTester tester,
  AccountOverviewRepository repository,
) async {
  await tester.runAsync(() => _mc.load());
  await tester.runAsync(() => _youtube.load());
  await tester.pumpWidget(_app(repository, _mc, _youtube));
  await tester.pumpAndSettle();
}

void main() {
  late AccountOverviewRepository repository;

  setUp(() {
    repository = AccountOverviewRepository();
    _mc = McContentRepository();
    _youtube = YoutubeRepository();
  });
  tearDown(() {
    repository.dispose();
    _mc.dispose();
    _youtube.dispose();
  });

  testWidgets('shows every section in the sidebar', (tester) async {
    await _pumpApp(tester, repository);

    for (final section in AccountSection.values) {
      // The rail is an accordion — only one service's sections show at a
      // time — so a section belonging to a folded-away service needs its
      // heading tapped open first.
      if (find.text(section.label).evaluate().isEmpty) {
        await tester.tap(find.text(section.service.label));
        await tester.pumpAndSettle();
      }
      expect(
        find.text(section.label),
        findsWidgets,
        reason: '${section.label} should be reachable from the rail',
      );
    }
  });

  testWidgets('asks for a token before showing any account data',
      (tester) async {
    await _pumpApp(tester, repository);

    expect(find.text('Connect your GitHub account'), findsOneWidget);
    expect(find.text('Connect GitHub'), findsOneWidget);
    // The privacy claim is load-bearing: it is the reason this plugin needs
    // no luma account, so it must not quietly disappear from the screen.
    expect(find.textContaining('luma server'), findsWidgets);
  });

  testWidgets('rail items are disabled while no account is connected',
      (tester) async {
    await _pumpApp(tester, repository);

    final overview = find.ancestor(
      of: find.text(AccountSection.repositories.label),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(overview.first).onTap, isNull);
  });

  testWidgets('the sidebar collapses to icons and back', (tester) async {
    await _pumpApp(tester, repository);

    expect(find.text('Collapse'), findsOneWidget);
    expect(find.text(AccountSection.usage.label), findsOneWidget);

    await tester.tap(find.text('Collapse'));
    await tester.pumpAndSettle();

    // Collapsed, the labels go but the destinations stay — as tooltips.
    expect(find.text('Collapse'), findsNothing);
    expect(find.text(AccountSection.usage.label), findsNothing);
    expect(find.byIcon(AccountSection.usage.icon), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_double_arrow_right_rounded));
    await tester.pumpAndSettle();
    expect(find.text(AccountSection.usage.label), findsOneWidget);
  });

  testWidgets('the connect dialog opens and names the scopes it needs',
      (tester) async {
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Connect GitHub'));
    await tester.pumpAndSettle();

    expect(find.text('Personal access token'), findsOneWidget);
    expect(find.text('read:user'), findsOneWidget);
    // The billing scope is what the usage meters depend on, so it has to be
    // spelled out where the token is created rather than discovered later.
    expect(find.text('user'), findsOneWidget);
  });

  testWidgets('renders at phone width without overflowing', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpApp(tester, repository, size: const Size(375, 812));

    expect(tester.takeException(), isNull);
  });

  group('connected', () {
    testWidgets('the overview shows the headline counts', (tester) async {
      repository.seedForTest(_populated());
      await _pumpSeeded(tester, repository);

      expect(find.text('Overview'), findsWidgets);
      expect(find.text('octo'), findsWidgets);
      expect(find.text('Stars earned'), findsOneWidget);
      // 12 + 3 stars, shown compactly.
      expect(find.text('15'), findsWidgets);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('1.2k'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the usage meters draw a bar only with an allowance',
        (tester) async {
      repository.seedForTest(
        _populated(),
        // Minutes have an allowance from GitHub itself; Copilot has none
        // recorded, which must read as "unknown", not as "zero".
        credentials: const GithubCredentials(token: 't', login: 'octo'),
      );
      await _pumpSeeded(tester, repository);

      await tester.tap(find.text(AccountSection.usage.label));
      await tester.pumpAndSettle();

      expect(find.text('GitHub Copilot'), findsOneWidget);
      expect(find.text('Workflow compute'), findsOneWidget);
      expect(find.textContaining('of 3,000 included'), findsOneWidget);
      expect(
        find.text('GitHub did not report an included allowance.'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a recorded Copilot allowance turns the meter into a bar',
        (tester) async {
      repository.seedForTest(
        _populated(),
        credentials: const GithubCredentials(
          token: 't',
          login: 'octo',
          copilotAllowance: 300,
        ),
      );
      await _pumpSeeded(tester, repository);

      await tester.tap(find.text(AccountSection.usage.label));
      await tester.pumpAndSettle();

      expect(find.textContaining('of 300 included'), findsOneWidget);
      // 240 of 300.
      expect(find.text('80%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every section renders without an exception', (tester) async {
      repository.seedForTest(_populated());
      await _pumpSeeded(tester, repository);

      for (final section in AccountSection.values) {
        // Accordion rail: fold the section's own service open first if it
        // is not the one currently expanded.
        if (find.text(section.label).evaluate().isEmpty) {
          await tester.tap(find.text(section.service.label));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(section.label).first);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${section.label} should render cleanly',
        );
      }
    });
  });
}

/// A snapshot with something in every section, so each tab has real content
/// to lay out rather than an empty state.
GithubSnapshot _populated() => GithubSnapshot(
      profile: const GithubProfile(
        login: 'octo',
        name: 'Octo Cat',
        avatarUrl: '',
        bio: 'Builds things',
        company: null,
        location: 'Delft',
        followers: 12,
        following: 3,
        publicRepos: 2,
        privateRepos: 1,
        createdAt: null,
        planName: 'pro',
      ),
      repos: [
        GithubRepo(
          name: 'luma',
          fullName: 'octo/luma',
          description: 'A utility app',
          isPrivate: false,
          isFork: false,
          isArchived: false,
          language: 'Dart',
          stars: 12,
          forks: 2,
          watchers: 4,
          openIssues: 3,
          sizeKb: 4096,
          pushedAt: DateTime(2026, 8, 20),
          htmlUrl: 'https://github.com/octo/luma',
          downloads: 1200,
          releases: 4,
        ),
        GithubRepo(
          name: 'tools',
          fullName: 'octo/tools',
          description: null,
          isPrivate: true,
          isFork: false,
          isArchived: false,
          language: 'Rust',
          stars: 3,
          forks: 0,
          watchers: 1,
          openIssues: 0,
          sizeKb: 512,
          pushedAt: DateTime(2026, 7, 2),
          htmlUrl: 'https://github.com/octo/tools',
        ),
      ],
      contributions: GithubContributions(
        totalCommits: 842,
        totalIssues: 6,
        totalPullRequests: 21,
        totalReviews: 4,
        restricted: 30,
        calendarTotal: 900,
        days: [
          for (var i = 0; i < 371; i++)
            GithubContributionDay(
              date: DateTime(2025, 9, 1).add(Duration(days: i)),
              count: i % 5,
            ),
        ],
      ),
      issues: [
        GithubIssue(
          title: 'Crash on launch',
          repo: 'octo/luma',
          number: 4,
          state: 'open',
          isPullRequest: false,
          isDraft: false,
          merged: false,
          updatedAt: DateTime(2026, 8, 30),
          comments: 2,
          htmlUrl: 'https://github.com/octo/luma/issues/4',
        ),
        GithubIssue(
          title: 'Add the usage meters',
          repo: 'octo/luma',
          number: 5,
          state: 'closed',
          isPullRequest: true,
          isDraft: false,
          merged: true,
          updatedAt: DateTime(2026, 8, 28),
          comments: 0,
          htmlUrl: 'https://github.com/octo/luma/pull/5',
        ),
      ],
      issueTotals: const GithubIssueTotals(
        openIssues: 3,
        closedIssues: 18,
        openPrs: 1,
        mergedPrs: 27,
      ),
      runs: [
        GithubWorkflowRun(
          name: 'release',
          repo: 'octo/luma',
          status: 'completed',
          conclusion: 'success',
          branch: 'master',
          event: 'push',
          runNumber: 91,
          startedAt: DateTime(2026, 8, 31, 10),
          updatedAt: DateTime(2026, 8, 31, 10, 12),
          htmlUrl: 'https://github.com/octo/luma/actions/runs/91',
        ),
        GithubWorkflowRun(
          name: 'tests',
          repo: 'octo/luma',
          status: 'completed',
          conclusion: 'failure',
          branch: 'master',
          event: 'push',
          runNumber: 90,
          startedAt: DateTime(2026, 8, 30, 9),
          updatedAt: DateTime(2026, 8, 30, 9, 4),
          htmlUrl: 'https://github.com/octo/luma/actions/runs/90',
        ),
      ],
      billing: const GithubBilling(
        available: true,
        unavailableReason: null,
        minutesUsed: 450,
        minutesIncluded: 3000,
        paidMinutesUsed: 0,
        minutesBreakdown: {'UBUNTU': 300, 'WINDOWS': 150},
        storageGbUsed: 1.75,
        bandwidthGbUsed: 2,
        bandwidthGbIncluded: 10,
        daysLeftInCycle: 11,
        usageItems: [
          GithubUsageItem(
            product: 'Copilot AI Credits',
            sku: 'AI Credit',
            unitType: 'ai-credits',
            quantity: 240,
            netAmount: 0,
            repository: null,
          ),
        ],
      ),
      fetchedAt: DateTime(2026, 9, 1),
    );
