import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'github_models.dart';

/// Raised when GitHub answers with something the UI needs to explain rather
/// than swallow — a bad token, a missing scope, an exhausted rate limit.
class GithubApiException implements Exception {
  GithubApiException(this.message, {this.statusCode, this.scopeRelated = false});

  final String message;
  final int? statusCode;

  /// True when the call would have worked with a broader token, which is a
  /// different fix from "try again later".
  final bool scopeRelated;

  @override
  String toString() => message;
}

/// A thin, read-only client for the parts of GitHub this plugin shows.
///
/// Every request goes straight from this device to api.github.com with the
/// user's own token. Nothing here touches a luma server, so
/// `GatedServerClient` and `SyncService.serverReady` are not in play — the
/// gate exists to keep luma-server traffic behind an approved account, and
/// there is no luma-server traffic here.
class GithubApi {
  GithubApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _rest = 'https://api.github.com';
  static const _graphql = 'https://api.github.com/graphql';

  /// GitHub asks every client to identify itself and to pin an API version.
  Map<String, String> _headers(String token) => {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'luma-account-overview',
      };

  void dispose() => _client.close();

  // ---- plumbing -------------------------------------------------------------

  Future<dynamic> _get(String token, String path, {bool allowNotFound = false}) async {
    final uri = path.startsWith('http') ? Uri.parse(path) : Uri.parse('$_rest$path');
    final response = await _client
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    if (allowNotFound &&
        (response.statusCode == 404 || response.statusCode == 403)) {
      return null;
    }
    throw _describe(response, uri);
  }

  GithubApiException _describe(http.Response response, Uri uri) {
    final code = response.statusCode;
    String? apiMessage;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map && body['message'] is String) {
        apiMessage = body['message'] as String;
      }
    } catch (_) {}

    // A 403 with the rate-limit counter at zero is a wait, not a scope
    // problem — telling the user to widen their token would send them off to
    // fix something that is not broken.
    final remaining = response.headers['x-ratelimit-remaining'];
    if (code == 403 && remaining == '0') {
      final reset = response.headers['x-ratelimit-reset'];
      final when = reset == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(int.parse(reset) * 1000);
      return GithubApiException(
        when == null
            ? 'GitHub rate limit reached. Try again shortly.'
            : 'GitHub rate limit reached. It resets at '
                '${when.hour.toString().padLeft(2, '0')}:'
                '${when.minute.toString().padLeft(2, '0')}.',
        statusCode: code,
      );
    }
    if (code == 401) {
      return GithubApiException(
        'GitHub rejected the token. It may have expired or been revoked.',
        statusCode: code,
      );
    }
    if (code == 403 || code == 404) {
      return GithubApiException(
        apiMessage ??
            'GitHub refused ${uri.path}. The token is probably missing a scope.',
        statusCode: code,
        scopeRelated: true,
      );
    }
    return GithubApiException(
      apiMessage ?? 'GitHub returned HTTP $code for ${uri.path}.',
      statusCode: code,
    );
  }

  /// Walks a paginated list endpoint until GitHub stops handing out pages.
  Future<List<Map<String, dynamic>>> _paged(
    String token,
    String path, {
    int maxPages = 10,
    int perPage = 100,
  }) async {
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final sep = path.contains('?') ? '&' : '?';
      final body = await _get(token, '$path${sep}per_page=$perPage&page=$page');
      if (body is! List || body.isEmpty) break;
      out.addAll(body.cast<Map<String, dynamic>>());
      if (body.length < perPage) break;
    }
    return out;
  }

  // ---- profile & repositories ----------------------------------------------

  /// Verifies a token and resolves the account behind it.
  Future<GithubProfile> fetchProfile(String token) async {
    final body = await _get(token, '/user');
    if (body is! Map<String, dynamic>) {
      throw GithubApiException('GitHub returned an unexpected profile payload.');
    }
    return GithubProfile.fromApi(body);
  }

  /// Every repository the account owns, private ones included when the token
  /// allows. Forks are kept — the Repositories tab filters them, which is a
  /// display choice, not something to decide out here.
  Future<List<GithubRepo>> fetchRepos(String token) async {
    final raw = await _paged(
      token,
      '/user/repos?affiliation=owner&sort=pushed',
      maxPages: 10,
    );
    return raw.map(GithubRepo.fromApi).toList();
  }

  /// Sums release-asset download counts.
  ///
  /// This is the one genuinely expensive sweep — one call per repository —
  /// so it is capped to the repositories most likely to have releases
  /// (biggest first) and runs a few at a time rather than all at once.
  Future<List<GithubRepo>> fetchDownloads(
    String token,
    List<GithubRepo> repos, {
    int maxRepos = 40,
    int concurrency = 5,
  }) async {
    final ordered = [...repos]..sort((a, b) {
        final byStars = b.stars.compareTo(a.stars);
        return byStars != 0 ? byStars : b.sizeKb.compareTo(a.sizeKb);
      });
    final targets = ordered.take(maxRepos).toList();
    final results = <String, GithubRepo>{};

    for (var i = 0; i < targets.length; i += concurrency) {
      final batch = targets.skip(i).take(concurrency);
      await Future.wait(batch.map((repo) async {
        try {
          final body = await _get(
            token,
            '/repos/${repo.fullName}/releases?per_page=100',
            allowNotFound: true,
          );
          if (body is! List) return;
          var downloads = 0;
          for (final release in body.cast<Map<String, dynamic>>()) {
            for (final asset
                in (release['assets'] as List<dynamic>? ?? const [])) {
              downloads +=
                  ((asset as Map<String, dynamic>)['download_count'] as num?)
                          ?.toInt() ??
                      0;
            }
          }
          results[repo.fullName] = repo.withDownloads(downloads, body.length);
        } catch (_) {
          // One unreadable repository must not lose the other thirty-nine.
        }
      }));
    }

    return [for (final repo in repos) results[repo.fullName] ?? repo];
  }

  // ---- contributions (GraphQL) ---------------------------------------------

  static const _contributionsQuery = r'''
query($login: String!) {
  user(login: $login) {
    contributionsCollection {
      totalCommitContributions
      totalIssueContributions
      totalPullRequestContributions
      totalPullRequestReviewContributions
      restrictedContributionsCount
      contributionCalendar {
        totalContributions
        weeks {
          contributionDays { date contributionCount }
        }
      }
    }
  }
}
''';

  /// The contribution calendar and its totals.
  ///
  /// REST has no commit-count endpoint at all, so this is the only way to
  /// answer "how many commits" without cloning every repository. A failure
  /// here is survivable: the rest of the page does not depend on it.
  Future<GithubContributions> fetchContributions(
      String token, String login) async {
    final response = await _client
        .post(
          Uri.parse(_graphql),
          headers: {..._headers(token), 'Content-Type': 'application/json'},
          body: jsonEncode({
            'query': _contributionsQuery,
            'variables': {'login': login},
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw _describe(response, Uri.parse(_graphql));
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) {
      throw GithubApiException('GitHub returned an unexpected GraphQL payload.');
    }
    // GraphQL reports its own errors inside a 200.
    if (body['errors'] is List && (body['errors'] as List).isNotEmpty) {
      final first = (body['errors'] as List).first;
      final message = first is Map ? first['message']?.toString() : null;
      throw GithubApiException(
        message ?? 'GitHub could not read your contribution graph.',
        scopeRelated: true,
      );
    }

    final collection = (((body['data'] as Map<String, dynamic>?)?['user']
            as Map<String, dynamic>?)?['contributionsCollection'])
        as Map<String, dynamic>?;
    if (collection == null) return GithubContributions.empty;

    final calendar =
        collection['contributionCalendar'] as Map<String, dynamic>? ?? const {};
    final days = <GithubContributionDay>[];
    for (final week in (calendar['weeks'] as List<dynamic>? ?? const [])) {
      for (final day in ((week as Map<String, dynamic>)['contributionDays']
              as List<dynamic>? ??
          const [])) {
        final entry = day as Map<String, dynamic>;
        final date = DateTime.tryParse(entry['date'] as String? ?? '');
        if (date == null) continue;
        days.add(GithubContributionDay(
          date: date,
          count: (entry['contributionCount'] as num?)?.toInt() ?? 0,
        ));
      }
    }
    days.sort((a, b) => a.date.compareTo(b.date));

    return GithubContributions(
      totalCommits:
          (collection['totalCommitContributions'] as num?)?.toInt() ?? 0,
      totalIssues: (collection['totalIssueContributions'] as num?)?.toInt() ?? 0,
      totalPullRequests:
          (collection['totalPullRequestContributions'] as num?)?.toInt() ?? 0,
      totalReviews:
          (collection['totalPullRequestReviewContributions'] as num?)?.toInt() ??
              0,
      restricted:
          (collection['restrictedContributionsCount'] as num?)?.toInt() ?? 0,
      calendarTotal: (calendar['totalContributions'] as num?)?.toInt() ?? 0,
      days: days,
    );
  }

  // ---- issues & pull requests ----------------------------------------------

  /// Counts issues and PRs with the search API.
  ///
  /// Search is rate-limited far more tightly than the rest of the API (30
  /// requests a minute), which is exactly why this asks for one item per
  /// query and reads `total_count` instead of paging.
  Future<GithubIssueTotals> fetchIssueTotals(String token, String login) async {
    Future<int> count(String query) async {
      final body = await _get(
        token,
        '/search/issues?q=${Uri.encodeQueryComponent(query)}&per_page=1',
        allowNotFound: true,
      );
      if (body is! Map<String, dynamic>) return 0;
      return (body['total_count'] as num?)?.toInt() ?? 0;
    }

    final results = await Future.wait([
      count('author:$login type:issue state:open'),
      count('author:$login type:issue state:closed'),
      count('author:$login type:pr state:open'),
      count('author:$login type:pr is:merged'),
    ]);

    return GithubIssueTotals(
      openIssues: results[0],
      closedIssues: results[1],
      openPrs: results[2],
      mergedPrs: results[3],
    );
  }

  /// The most recently touched issues and PRs involving the account.
  Future<List<GithubIssue>> fetchRecentIssues(
      String token, String login) async {
    final body = await _get(
      token,
      '/search/issues?q=${Uri.encodeQueryComponent('involves:$login')}'
      '&sort=updated&order=desc&per_page=50',
      allowNotFound: true,
    );
    if (body is! Map<String, dynamic>) return const [];
    final items = body['items'] as List<dynamic>? ?? const [];
    return items
        .cast<Map<String, dynamic>>()
        .map(GithubIssue.fromApi)
        .toList();
  }

  // ---- actions --------------------------------------------------------------

  /// Recent workflow runs across the account's most active repositories.
  ///
  /// There is no cross-repository runs endpoint, so this asks the
  /// most-recently-pushed repositories only — the ones whose CI could
  /// plausibly have run lately.
  Future<List<GithubWorkflowRun>> fetchWorkflowRuns(
    String token,
    List<GithubRepo> repos, {
    int maxRepos = 12,
    int runsPerRepo = 15,
  }) async {
    final ordered = [...repos.where((r) => !r.isArchived)]..sort((a, b) {
        final at = a.pushedAt, bt = b.pushedAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

    final runs = <GithubWorkflowRun>[];
    await Future.wait(ordered.take(maxRepos).map((repo) async {
      try {
        final body = await _get(
          token,
          '/repos/${repo.fullName}/actions/runs?per_page=$runsPerRepo',
          allowNotFound: true,
        );
        if (body is! Map<String, dynamic>) return;
        for (final run
            in (body['workflow_runs'] as List<dynamic>? ?? const [])) {
          runs.add(GithubWorkflowRun.fromApi(
              run as Map<String, dynamic>, repo.fullName));
        }
      } catch (_) {
        // A repository with Actions disabled is normal, not an error.
      }
    }));

    runs.sort((a, b) {
      final at = a.startedAt, bt = b.startedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return runs;
  }

  // ---- billing --------------------------------------------------------------

  /// Reads whatever the billing endpoints will give up.
  ///
  /// Two generations of API are queried because neither alone is enough:
  /// the legacy per-product endpoints are the only ones that state an
  /// *included allowance*, while the enhanced usage endpoint is the only one
  /// that still reports Copilot. Both are optional — a token without the
  /// billing scope leaves the section explaining itself rather than failing
  /// the whole page.
  Future<GithubBilling> fetchBilling(String token, String login) async {
    var billing = GithubBilling.empty;
    final failures = <String>[];

    Future<Map<String, dynamic>?> legacy(String product) async {
      try {
        final body = await _get(
          token,
          '/users/$login/settings/billing/$product',
          allowNotFound: true,
        );
        return body as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    }

    final actions = await legacy('actions');
    if (actions != null) {
      billing = billing.copyWith(
        available: true,
        minutesUsed: (actions['total_minutes_used'] as num?)?.toDouble() ?? 0,
        minutesIncluded: (actions['included_minutes'] as num?)?.toDouble() ?? 0,
        paidMinutesUsed:
            (actions['total_paid_minutes_used'] as num?)?.toDouble() ?? 0,
        minutesBreakdown: {
          for (final e
              in (actions['minutes_used_breakdown'] as Map<String, dynamic>? ??
                      const {})
                  .entries)
            if (e.value is num && (e.value as num) > 0)
              e.key: (e.value as num).toDouble(),
        },
      );
    } else {
      failures.add('Actions minutes');
    }

    final storage = await legacy('shared-storage');
    if (storage != null) {
      billing = billing.copyWith(
        available: true,
        storageGbUsed:
            (storage['estimated_storage_for_month'] as num?)?.toDouble() ?? 0,
        daysLeftInCycle:
            (storage['days_left_in_billing_cycle'] as num?)?.toInt() ?? 0,
      );
    } else {
      failures.add('shared storage');
    }

    final packages = await legacy('packages');
    if (packages != null) {
      billing = billing.copyWith(
        available: true,
        bandwidthGbUsed:
            (packages['total_gigabytes_bandwidth_used'] as num?)?.toDouble() ??
                0,
        bandwidthGbIncluded:
            (packages['included_gigabytes_bandwidth'] as num?)?.toDouble() ?? 0,
      );
    }

    // The enhanced billing platform: the only source that still reports
    // Copilot consumption for a personal account.
    try {
      final now = DateTime.now();
      final body = await _get(
        token,
        '/users/$login/settings/billing/usage?year=${now.year}&month=${now.month}',
        allowNotFound: true,
      );
      if (body is Map<String, dynamic>) {
        final items = (body['usageItems'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(GithubUsageItem.fromApi)
            .toList();
        billing = billing.copyWith(available: true, usageItems: items);
      } else {
        failures.add('Copilot usage');
      }
    } catch (_) {
      failures.add('Copilot usage');
    }

    if (!billing.available) {
      return GithubBilling.empty.copyWith(
        unavailableReason: 'This token cannot read billing. A classic token '
            'needs the "user" scope; a fine-grained token needs the '
            '"Plan" permission (read-only).',
      );
    }
    if (failures.isNotEmpty) {
      return billing.copyWith(
        unavailableReason: 'GitHub did not return ${failures.join(', ')} for '
            'this account.',
      );
    }
    return billing;
  }
}
