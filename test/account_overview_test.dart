import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:luma/features/plugins/installed/account_overview/github_api.dart';
import 'package:luma/features/plugins/installed/account_overview/github_models.dart';
import 'package:luma/features/plugins/installed/account_overview/ui/account_shared.dart';

/// A day's worth of contribution calendar, `counts` read left to right from
/// [start].
List<GithubContributionDay> _days(DateTime start, List<int> counts) => [
      for (var i = 0; i < counts.length; i++)
        GithubContributionDay(
          date: start.add(Duration(days: i)),
          count: counts[i],
        ),
    ];

GithubRepo _repo(
  String name, {
  int stars = 0,
  int forks = 0,
  int downloads = 0,
  int sizeKb = 0,
  String? language,
}) =>
    GithubRepo(
      name: name,
      fullName: 'octo/$name',
      description: null,
      isPrivate: false,
      isFork: false,
      isArchived: false,
      language: language,
      stars: stars,
      forks: forks,
      watchers: 0,
      openIssues: 0,
      sizeKb: sizeKb,
      pushedAt: DateTime(2026, 8, 1),
      htmlUrl: 'https://github.com/octo/$name',
      downloads: downloads,
    );

GithubSnapshot _snapshot({
  List<GithubRepo> repos = const [],
  GithubContributions? contributions,
  GithubBilling? billing,
}) =>
    GithubSnapshot(
      profile: const GithubProfile(
        login: 'octo',
        name: 'Octo Cat',
        avatarUrl: 'https://example.invalid/a.png',
        bio: null,
        company: null,
        location: null,
        followers: 12,
        following: 3,
        publicRepos: 4,
        privateRepos: 1,
        createdAt: null,
        planName: 'pro',
      ),
      repos: repos,
      contributions: contributions ?? GithubContributions.empty,
      issues: const [],
      issueTotals: GithubIssueTotals.empty,
      runs: const [],
      billing: billing ?? GithubBilling.empty,
      fetchedAt: DateTime(2026, 9, 1),
    );

void main() {
  group('contribution calendar', () {
    test('longest streak spans the best unbroken run', () {
      final contributions = GithubContributions(
        totalCommits: 9,
        totalIssues: 0,
        totalPullRequests: 0,
        totalReviews: 0,
        restricted: 0,
        calendarTotal: 9,
        days: _days(DateTime(2026, 1, 1), [1, 2, 0, 1, 1, 1, 0, 3]),
      );

      expect(contributions.longestStreak, 3);
      expect(contributions.busiestDay, 3);
    });

    test('current streak counts back from the most recent day', () {
      final contributions = GithubContributions(
        totalCommits: 0,
        totalIssues: 0,
        totalPullRequests: 0,
        totalReviews: 0,
        restricted: 0,
        calendarTotal: 0,
        days: _days(DateTime(2026, 1, 1), [0, 1, 1, 1]),
      );

      expect(contributions.currentStreak, 3);
    });

    test('an empty final day does not break the streak yet', () {
      // Today with no commits on it is a day still in progress, not a
      // streak that has ended.
      final contributions = GithubContributions(
        totalCommits: 0,
        totalIssues: 0,
        totalPullRequests: 0,
        totalReviews: 0,
        restricted: 0,
        calendarTotal: 0,
        days: _days(DateTime(2026, 1, 1), [1, 1, 0]),
      );

      expect(contributions.currentStreak, 2);
    });
  });

  group('snapshot totals', () {
    test('sums stars, forks and downloads across repositories', () {
      final snapshot = _snapshot(repos: [
        _repo('a', stars: 10, forks: 2, downloads: 100, sizeKb: 2048),
        _repo('b', stars: 5, forks: 1, downloads: 40, sizeKb: 1024),
      ]);

      expect(snapshot.totalStars, 15);
      expect(snapshot.totalForks, 3);
      expect(snapshot.totalDownloads, 140);
      expect(snapshot.totalSizeMb, closeTo(3.0, 0.001));
    });

    test('language counts ignore repositories with no language', () {
      final snapshot = _snapshot(repos: [
        _repo('a', language: 'Dart'),
        _repo('b', language: 'Dart'),
        _repo('c', language: 'Rust'),
        _repo('d'),
      ]);

      expect(snapshot.languageCounts, {'Dart': 2, 'Rust': 1});
    });

    test('round-trips through JSON', () {
      final original = _snapshot(
        repos: [_repo('a', stars: 3, downloads: 7, language: 'Dart')],
        contributions: GithubContributions(
          totalCommits: 42,
          totalIssues: 1,
          totalPullRequests: 2,
          totalReviews: 3,
          restricted: 4,
          calendarTotal: 52,
          days: _days(DateTime(2026, 1, 1), [1, 0, 2]),
        ),
      );

      final restored =
          GithubSnapshot.fromJson(jsonDecode(jsonEncode(original.toJson())));

      expect(restored.profile!.login, 'octo');
      expect(restored.totalStars, 3);
      expect(restored.totalDownloads, 7);
      expect(restored.contributions.totalCommits, 42);
      expect(restored.contributions.days.length, 3);
      expect(restored.fetchedAt, original.fetchedAt);
    });
  });

  group('billing', () {
    GithubBilling billingWith(List<GithubUsageItem> items) =>
        GithubBilling.empty.copyWith(available: true, usageItems: items);

    test('picks out Copilot lines and totals them', () {
      final billing = billingWith(const [
        GithubUsageItem(
          product: 'Copilot AI Credits',
          sku: 'AI Credit',
          unitType: 'ai-credits',
          quantity: 120,
          netAmount: 1.2,
          repository: null,
        ),
        GithubUsageItem(
          product: 'Actions',
          sku: 'Ubuntu',
          unitType: 'minutes',
          quantity: 300,
          netAmount: 0,
          repository: 'octo/a',
        ),
      ]);

      expect(billing.copilotItems.length, 1);
      expect(billing.copilotQuantity, 120);
      expect(billing.copilotSpend, closeTo(1.2, 0.0001));
      // The unit is read from the payload, not assumed, so a rename on
      // GitHub's side relabels the meter instead of mislabelling it.
      expect(billing.copilotUnit, 'ai-credits');
      expect(billing.actionsItems.length, 1);
      expect(billing.totalSpend, closeTo(1.2, 0.0001));
    });

    test('falls back to a generic unit when none is reported', () {
      final billing = billingWith(const [
        GithubUsageItem(
          product: 'GitHub Copilot',
          sku: '',
          unitType: '',
          quantity: 5,
          netAmount: 0,
          repository: null,
        ),
      ]);

      expect(billing.copilotUnit, 'requests');
    });

    test('reads either quantity spelling the API has used', () {
      final net = GithubUsageItem.fromApi(const {
        'product': 'Copilot',
        'netQuantity': 90,
        'grossQuantity': 100,
        'netAmount': 0,
      });
      final plain = GithubUsageItem.fromApi(const {
        'product': 'Copilot',
        'quantity': 25,
        'netAmount': 0,
      });

      expect(net.quantity, 90);
      expect(plain.quantity, 25);
    });
  });

  group('GithubApi', () {
    test('parses the profile', () async {
      final api = GithubApi(
        client: MockClient((request) async {
          expect(request.url.path, '/user');
          expect(request.headers['Authorization'], 'Bearer tok');
          return http.Response(
            jsonEncode({
              'login': 'octo',
              'name': 'Octo Cat',
              'avatar_url': 'https://example.invalid/a.png',
              'followers': 12,
              'following': 3,
              'public_repos': 4,
              'total_private_repos': 2,
              'plan': {'name': 'pro'},
            }),
            200,
          );
        }),
      );

      final profile = await api.fetchProfile('tok');
      expect(profile.login, 'octo');
      expect(profile.privateRepos, 2);
      expect(profile.planName, 'pro');
    });

    test('explains a rate limit differently from a missing scope', () async {
      final limited = GithubApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({'message': 'API rate limit exceeded'}),
              403,
              headers: {'x-ratelimit-remaining': '0'},
            )),
      );
      final forbidden = GithubApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({'message': 'Resource not accessible'}),
              403,
              headers: {'x-ratelimit-remaining': '42'},
            )),
      );

      await expectLater(
        limited.fetchProfile('tok'),
        throwsA(isA<GithubApiException>()
            .having((e) => e.scopeRelated, 'scopeRelated', isFalse)
            .having((e) => e.message, 'message', contains('rate limit'))),
      );
      await expectLater(
        forbidden.fetchProfile('tok'),
        throwsA(isA<GithubApiException>()
            .having((e) => e.scopeRelated, 'scopeRelated', isTrue)),
      );
    });

    test('flattens the GraphQL contribution calendar in date order', () async {
      final api = GithubApi(
        client: MockClient((request) async {
          expect(request.url.host, 'api.github.com');
          expect(request.url.path, '/graphql');
          return http.Response(
            jsonEncode({
              'data': {
                'user': {
                  'contributionsCollection': {
                    'totalCommitContributions': 128,
                    'totalIssueContributions': 4,
                    'totalPullRequestContributions': 9,
                    'totalPullRequestReviewContributions': 2,
                    'restrictedContributionsCount': 30,
                    'contributionCalendar': {
                      'totalContributions': 173,
                      'weeks': [
                        {
                          'contributionDays': [
                            {'date': '2026-01-02', 'contributionCount': 2},
                            {'date': '2026-01-01', 'contributionCount': 1},
                          ],
                        },
                      ],
                    },
                  },
                },
              },
            }),
            200,
          );
        }),
      );

      final contributions = await api.fetchContributions('tok', 'octo');
      expect(contributions.totalCommits, 128);
      expect(contributions.restricted, 30);
      expect(contributions.days.first.date, DateTime.parse('2026-01-01'));
      expect(contributions.days.last.count, 2);
    });

    test('surfaces GraphQL errors returned inside a 200', () async {
      final api = GithubApi(
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'errors': [
                  {'message': 'Requires read:user'}
                ],
              }),
              200,
            )),
      );

      await expectLater(
        api.fetchContributions('tok', 'octo'),
        throwsA(isA<GithubApiException>()
            .having((e) => e.message, 'message', contains('read:user'))),
      );
    });

    test('billing without any readable endpoint says why, not zero', () async {
      final api = GithubApi(
        client: MockClient((_) async => http.Response('{}', 403)),
      );

      final billing = await api.fetchBilling('tok', 'octo');
      expect(billing.available, isFalse);
      expect(billing.unavailableReason, contains('Plan'));
    });

    test('merges the legacy allowance endpoints with the usage report',
        () async {
      final api = GithubApi(
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/billing/actions')) {
            return http.Response(
              jsonEncode({
                'total_minutes_used': 450,
                'total_paid_minutes_used': 0,
                'included_minutes': 3000,
                'minutes_used_breakdown': {
                  'UBUNTU': 300,
                  'WINDOWS': 150,
                  'MACOS': 0,
                },
              }),
              200,
            );
          }
          if (path.endsWith('/billing/shared-storage')) {
            return http.Response(
              jsonEncode({
                'days_left_in_billing_cycle': 11,
                'estimated_storage_for_month': 1.75,
              }),
              200,
            );
          }
          if (path.endsWith('/billing/packages')) {
            return http.Response(
              jsonEncode({
                'total_gigabytes_bandwidth_used': 2,
                'included_gigabytes_bandwidth': 10,
              }),
              200,
            );
          }
          if (path.endsWith('/billing/usage')) {
            return http.Response(
              jsonEncode({
                'usageItems': [
                  {
                    'product': 'Copilot AI Credits',
                    'sku': 'AI Credit',
                    'unitType': 'ai-credits',
                    'netQuantity': 240,
                    'netAmount': 0,
                  },
                ],
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      final billing = await api.fetchBilling('tok', 'octo');
      expect(billing.available, isTrue);
      expect(billing.unavailableReason, isNull);
      expect(billing.minutesUsed, 450);
      expect(billing.minutesIncluded, 3000);
      // Zeroed runners are noise in a breakdown that is meant to explain
      // where the minutes went.
      expect(billing.minutesBreakdown.containsKey('MACOS'), isFalse);
      expect(billing.minutesBreakdown['UBUNTU'], 300);
      expect(billing.storageGbUsed, 1.75);
      expect(billing.daysLeftInCycle, 11);
      expect(billing.bandwidthGbIncluded, 10);
      expect(billing.copilotQuantity, 240);
    });

    test('one unreadable repository does not lose the others downloads',
        () async {
      final api = GithubApi(
        client: MockClient((request) async {
          if (request.url.path.contains('/repos/octo/broken/releases')) {
            return http.Response('{}', 404);
          }
          return http.Response(
            jsonEncode([
              {
                'assets': [
                  {'download_count': 12},
                  {'download_count': 30},
                ],
              },
            ]),
            200,
          );
        }),
      );

      final repos = await api.fetchDownloads(
        'tok',
        [_repo('good', stars: 5), _repo('broken', stars: 1)],
      );

      expect(repos.firstWhere((r) => r.name == 'good').downloads, 42);
      expect(repos.firstWhere((r) => r.name == 'broken').downloads, 0);
      expect(repos.length, 2);
    });
  });

  group('formatting', () {
    test('groups thousands', () {
      expect(formatCount(0), '0');
      expect(formatCount(999), '999');
      expect(formatCount(1234), '1,234');
      expect(formatCount(1234567), '1,234,567');
    });

    test('compacts large counts', () {
      expect(formatCompact(999), '999');
      expect(formatCompact(1500), '1.5k');
      expect(formatCompact(24000), '24k');
      expect(formatCompact(3100000), '3.1M');
    });

    test('language colours are stable per name and differ between names', () {
      expect(languageColor('Dart'), languageColor('Dart'));
      expect(languageColor('Dart'), isNot(languageColor('Rust')));
    });

    test('sizes step up through the units', () {
      expect(formatBytesFromKb(512), '512 KB');
      expect(formatBytesFromKb(2048), '2.0 MB');
      expect(formatBytesFromKb(1024 * 1024 * 3), '3.00 GB');
    });
  });
}
