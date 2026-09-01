/// Plain data for everything the GitHub section shows.
///
/// Every model is JSON-round-trippable: the repository caches the whole
/// snapshot to disk so reopening the plugin paints instantly instead of
/// staring at a spinner while a dozen API calls run again.
library;

/// The signed-in account.
class GithubProfile {
  const GithubProfile({
    required this.login,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.company,
    required this.location,
    required this.followers,
    required this.following,
    required this.publicRepos,
    required this.privateRepos,
    required this.createdAt,
    required this.planName,
  });

  final String login;
  final String? name;
  final String avatarUrl;
  final String? bio;
  final String? company;
  final String? location;
  final int followers;
  final int following;
  final int publicRepos;
  final int privateRepos;
  final DateTime? createdAt;

  /// `plan.name` from `/user` — "free", "pro", "team". Only present when the
  /// token carries the `user` scope.
  final String? planName;

  String get displayName => (name != null && name!.isNotEmpty) ? name! : login;

  String get htmlUrl => 'https://github.com/$login';

  factory GithubProfile.fromApi(Map<String, dynamic> j) => GithubProfile(
        login: j['login'] as String? ?? '',
        name: j['name'] as String?,
        avatarUrl: j['avatar_url'] as String? ?? '',
        bio: j['bio'] as String?,
        company: j['company'] as String?,
        location: j['location'] as String?,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        following: (j['following'] as num?)?.toInt() ?? 0,
        publicRepos: (j['public_repos'] as num?)?.toInt() ?? 0,
        privateRepos: (j['total_private_repos'] as num?)?.toInt() ??
            (j['owned_private_repos'] as num?)?.toInt() ??
            0,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
        planName: (j['plan'] as Map<String, dynamic>?)?['name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'login': login,
        'name': name,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'company': company,
        'location': location,
        'followers': followers,
        'following': following,
        'publicRepos': publicRepos,
        'privateRepos': privateRepos,
        'createdAt': createdAt?.toIso8601String(),
        'planName': planName,
      };

  factory GithubProfile.fromJson(Map<String, dynamic> j) => GithubProfile(
        login: j['login'] as String,
        name: j['name'] as String?,
        avatarUrl: j['avatarUrl'] as String? ?? '',
        bio: j['bio'] as String?,
        company: j['company'] as String?,
        location: j['location'] as String?,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        following: (j['following'] as num?)?.toInt() ?? 0,
        publicRepos: (j['publicRepos'] as num?)?.toInt() ?? 0,
        privateRepos: (j['privateRepos'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        planName: j['planName'] as String?,
      );
}

/// One repository the account owns.
class GithubRepo {
  const GithubRepo({
    required this.name,
    required this.fullName,
    required this.description,
    required this.isPrivate,
    required this.isFork,
    required this.isArchived,
    required this.language,
    required this.stars,
    required this.forks,
    required this.watchers,
    required this.openIssues,
    required this.sizeKb,
    required this.pushedAt,
    required this.htmlUrl,
    this.downloads = 0,
    this.releases = 0,
  });

  final String name;
  final String fullName;
  final String? description;
  final bool isPrivate;
  final bool isFork;
  final bool isArchived;
  final String? language;
  final int stars;
  final int forks;
  final int watchers;

  /// GitHub's `open_issues_count` counts open pull requests too — that is
  /// the API's definition, not a bug here, and the Issues tab pulls the
  /// split apart with the search API.
  final int openIssues;
  final int sizeKb;
  final DateTime? pushedAt;
  final String htmlUrl;

  /// Total release-asset downloads. Filled in by a second pass, so it is
  /// zero until the release sweep finishes.
  final int downloads;
  final int releases;

  GithubRepo withDownloads(int downloads, int releases) => GithubRepo(
        name: name,
        fullName: fullName,
        description: description,
        isPrivate: isPrivate,
        isFork: isFork,
        isArchived: isArchived,
        language: language,
        stars: stars,
        forks: forks,
        watchers: watchers,
        openIssues: openIssues,
        sizeKb: sizeKb,
        pushedAt: pushedAt,
        htmlUrl: htmlUrl,
        downloads: downloads,
        releases: releases,
      );

  factory GithubRepo.fromApi(Map<String, dynamic> j) => GithubRepo(
        name: j['name'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        description: j['description'] as String?,
        isPrivate: j['private'] as bool? ?? false,
        isFork: j['fork'] as bool? ?? false,
        isArchived: j['archived'] as bool? ?? false,
        language: j['language'] as String?,
        stars: (j['stargazers_count'] as num?)?.toInt() ?? 0,
        forks: (j['forks_count'] as num?)?.toInt() ?? 0,
        watchers: (j['subscribers_count'] as num?)?.toInt() ??
            (j['watchers_count'] as num?)?.toInt() ??
            0,
        openIssues: (j['open_issues_count'] as num?)?.toInt() ?? 0,
        sizeKb: (j['size'] as num?)?.toInt() ?? 0,
        pushedAt: DateTime.tryParse(j['pushed_at'] as String? ?? ''),
        htmlUrl: j['html_url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'fullName': fullName,
        'description': description,
        'isPrivate': isPrivate,
        'isFork': isFork,
        'isArchived': isArchived,
        'language': language,
        'stars': stars,
        'forks': forks,
        'watchers': watchers,
        'openIssues': openIssues,
        'sizeKb': sizeKb,
        'pushedAt': pushedAt?.toIso8601String(),
        'htmlUrl': htmlUrl,
        'downloads': downloads,
        'releases': releases,
      };

  factory GithubRepo.fromJson(Map<String, dynamic> j) => GithubRepo(
        name: j['name'] as String,
        fullName: j['fullName'] as String? ?? '',
        description: j['description'] as String?,
        isPrivate: j['isPrivate'] as bool? ?? false,
        isFork: j['isFork'] as bool? ?? false,
        isArchived: j['isArchived'] as bool? ?? false,
        language: j['language'] as String?,
        stars: (j['stars'] as num?)?.toInt() ?? 0,
        forks: (j['forks'] as num?)?.toInt() ?? 0,
        watchers: (j['watchers'] as num?)?.toInt() ?? 0,
        openIssues: (j['openIssues'] as num?)?.toInt() ?? 0,
        sizeKb: (j['sizeKb'] as num?)?.toInt() ?? 0,
        pushedAt: DateTime.tryParse(j['pushedAt'] as String? ?? ''),
        htmlUrl: j['htmlUrl'] as String? ?? '',
        downloads: (j['downloads'] as num?)?.toInt() ?? 0,
        releases: (j['releases'] as num?)?.toInt() ?? 0,
      );
}

/// A single day on the contribution calendar.
class GithubContributionDay {
  const GithubContributionDay({required this.date, required this.count});

  final DateTime date;
  final int count;

  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'count': count};

  factory GithubContributionDay.fromJson(Map<String, dynamic> j) =>
      GithubContributionDay(
        date: DateTime.parse(j['date'] as String),
        count: (j['count'] as num).toInt(),
      );
}

/// The GraphQL `contributionsCollection` — the numbers behind the green
/// squares, which REST simply does not expose.
class GithubContributions {
  const GithubContributions({
    required this.totalCommits,
    required this.totalIssues,
    required this.totalPullRequests,
    required this.totalReviews,
    required this.restricted,
    required this.calendarTotal,
    required this.days,
  });

  /// Commits authored in the last year, public plus (with the right scope)
  /// private. This is GitHub's own "commit contributions" definition, not a
  /// count of every commit ever pushed — nothing on the API offers that.
  final int totalCommits;
  final int totalIssues;
  final int totalPullRequests;
  final int totalReviews;

  /// Contributions in private repos the viewer cannot see broken down.
  final int restricted;
  final int calendarTotal;
  final List<GithubContributionDay> days;

  static const empty = GithubContributions(
    totalCommits: 0,
    totalIssues: 0,
    totalPullRequests: 0,
    totalReviews: 0,
    restricted: 0,
    calendarTotal: 0,
    days: [],
  );

  /// The longest run of consecutive days with at least one contribution.
  int get longestStreak {
    var best = 0;
    var run = 0;
    for (final day in days) {
      if (day.count > 0) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  /// The streak ending today (or yesterday — a day with no contributions yet
  /// should not read as a broken streak before it is over).
  int get currentStreak {
    if (days.isEmpty) return 0;
    var streak = 0;
    for (var i = days.length - 1; i >= 0; i--) {
      if (days[i].count > 0) {
        streak++;
      } else if (i == days.length - 1) {
        continue;
      } else {
        break;
      }
    }
    return streak;
  }

  int get busiestDay =>
      days.isEmpty ? 0 : days.map((d) => d.count).reduce((a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
        'totalCommits': totalCommits,
        'totalIssues': totalIssues,
        'totalPullRequests': totalPullRequests,
        'totalReviews': totalReviews,
        'restricted': restricted,
        'calendarTotal': calendarTotal,
        'days': days.map((d) => d.toJson()).toList(),
      };

  factory GithubContributions.fromJson(Map<String, dynamic> j) =>
      GithubContributions(
        totalCommits: (j['totalCommits'] as num?)?.toInt() ?? 0,
        totalIssues: (j['totalIssues'] as num?)?.toInt() ?? 0,
        totalPullRequests: (j['totalPullRequests'] as num?)?.toInt() ?? 0,
        totalReviews: (j['totalReviews'] as num?)?.toInt() ?? 0,
        restricted: (j['restricted'] as num?)?.toInt() ?? 0,
        calendarTotal: (j['calendarTotal'] as num?)?.toInt() ?? 0,
        days: (j['days'] as List<dynamic>? ?? [])
            .map((e) => GithubContributionDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// An issue or pull request authored by, or assigned to, the account.
class GithubIssue {
  const GithubIssue({
    required this.title,
    required this.repo,
    required this.number,
    required this.state,
    required this.isPullRequest,
    required this.isDraft,
    required this.merged,
    required this.updatedAt,
    required this.comments,
    required this.htmlUrl,
  });

  final String title;
  final String repo;
  final int number;
  final String state;
  final bool isPullRequest;
  final bool isDraft;
  final bool merged;
  final DateTime? updatedAt;
  final int comments;
  final String htmlUrl;

  bool get isOpen => state == 'open';

  factory GithubIssue.fromApi(Map<String, dynamic> j) {
    final url = j['html_url'] as String? ?? '';
    final pr = j['pull_request'] as Map<String, dynamic>?;
    return GithubIssue(
      title: j['title'] as String? ?? '',
      repo: _repoFromUrl(url),
      number: (j['number'] as num?)?.toInt() ?? 0,
      state: j['state'] as String? ?? 'open',
      isPullRequest: pr != null,
      isDraft: j['draft'] as bool? ?? false,
      merged: pr?['merged_at'] != null,
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? ''),
      comments: (j['comments'] as num?)?.toInt() ?? 0,
      htmlUrl: url,
    );
  }

  /// `https://github.com/owner/repo/issues/12` -> `owner/repo`.
  static String _repoFromUrl(String url) {
    final parts = Uri.tryParse(url)?.pathSegments ?? const [];
    if (parts.length < 2) return '';
    return '${parts[0]}/${parts[1]}';
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'repo': repo,
        'number': number,
        'state': state,
        'isPullRequest': isPullRequest,
        'isDraft': isDraft,
        'merged': merged,
        'updatedAt': updatedAt?.toIso8601String(),
        'comments': comments,
        'htmlUrl': htmlUrl,
      };

  factory GithubIssue.fromJson(Map<String, dynamic> j) => GithubIssue(
        title: j['title'] as String? ?? '',
        repo: j['repo'] as String? ?? '',
        number: (j['number'] as num?)?.toInt() ?? 0,
        state: j['state'] as String? ?? 'open',
        isPullRequest: j['isPullRequest'] as bool? ?? false,
        isDraft: j['isDraft'] as bool? ?? false,
        merged: j['merged'] as bool? ?? false,
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
        comments: (j['comments'] as num?)?.toInt() ?? 0,
        htmlUrl: j['htmlUrl'] as String? ?? '',
      );
}

/// Totals from the search API, which counts far more cheaply than paging
/// every issue in every repository.
class GithubIssueTotals {
  const GithubIssueTotals({
    required this.openIssues,
    required this.closedIssues,
    required this.openPrs,
    required this.mergedPrs,
  });

  final int openIssues;
  final int closedIssues;
  final int openPrs;
  final int mergedPrs;

  static const empty =
      GithubIssueTotals(openIssues: 0, closedIssues: 0, openPrs: 0, mergedPrs: 0);

  Map<String, dynamic> toJson() => {
        'openIssues': openIssues,
        'closedIssues': closedIssues,
        'openPrs': openPrs,
        'mergedPrs': mergedPrs,
      };

  factory GithubIssueTotals.fromJson(Map<String, dynamic> j) =>
      GithubIssueTotals(
        openIssues: (j['openIssues'] as num?)?.toInt() ?? 0,
        closedIssues: (j['closedIssues'] as num?)?.toInt() ?? 0,
        openPrs: (j['openPrs'] as num?)?.toInt() ?? 0,
        mergedPrs: (j['mergedPrs'] as num?)?.toInt() ?? 0,
      );
}

/// One Actions workflow run.
class GithubWorkflowRun {
  const GithubWorkflowRun({
    required this.name,
    required this.repo,
    required this.status,
    required this.conclusion,
    required this.branch,
    required this.event,
    required this.runNumber,
    required this.startedAt,
    required this.updatedAt,
    required this.htmlUrl,
  });

  final String name;
  final String repo;

  /// `queued`, `in_progress`, `completed`.
  final String status;

  /// `success`, `failure`, `cancelled`, `skipped`… null while running.
  final String? conclusion;
  final String branch;
  final String event;
  final int runNumber;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final String htmlUrl;

  bool get isRunning => status != 'completed';
  bool get succeeded => conclusion == 'success';
  bool get failed => conclusion == 'failure' || conclusion == 'timed_out';

  Duration? get duration {
    if (startedAt == null || updatedAt == null) return null;
    final d = updatedAt!.difference(startedAt!);
    return d.isNegative ? null : d;
  }

  factory GithubWorkflowRun.fromApi(Map<String, dynamic> j, String repo) =>
      GithubWorkflowRun(
        name: j['name'] as String? ?? j['display_title'] as String? ?? 'Workflow',
        repo: repo,
        status: j['status'] as String? ?? 'completed',
        conclusion: j['conclusion'] as String?,
        branch: j['head_branch'] as String? ?? '',
        event: j['event'] as String? ?? '',
        runNumber: (j['run_number'] as num?)?.toInt() ?? 0,
        startedAt: DateTime.tryParse(
            j['run_started_at'] as String? ?? j['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? ''),
        htmlUrl: j['html_url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'repo': repo,
        'status': status,
        'conclusion': conclusion,
        'branch': branch,
        'event': event,
        'runNumber': runNumber,
        'startedAt': startedAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'htmlUrl': htmlUrl,
      };

  factory GithubWorkflowRun.fromJson(Map<String, dynamic> j) =>
      GithubWorkflowRun(
        name: j['name'] as String? ?? '',
        repo: j['repo'] as String? ?? '',
        status: j['status'] as String? ?? 'completed',
        conclusion: j['conclusion'] as String?,
        branch: j['branch'] as String? ?? '',
        event: j['event'] as String? ?? '',
        runNumber: (j['runNumber'] as num?)?.toInt() ?? 0,
        startedAt: DateTime.tryParse(j['startedAt'] as String? ?? ''),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
        htmlUrl: j['htmlUrl'] as String? ?? '',
      );
}

/// One line of the enhanced billing platform's usage report.
class GithubUsageItem {
  const GithubUsageItem({
    required this.product,
    required this.sku,
    required this.unitType,
    required this.quantity,
    required this.netAmount,
    required this.repository,
  });

  final String product;
  final String sku;
  final String unitType;
  final double quantity;
  final double netAmount;
  final String? repository;

  /// GitHub has moved this payload around more than once (premium requests
  /// became AI credits; `quantity` gained `gross`/`net` variants), so every
  /// field is read leniently and a missing one is a zero, never a throw.
  factory GithubUsageItem.fromApi(Map<String, dynamic> j) => GithubUsageItem(
        product: j['product'] as String? ?? 'Unknown',
        sku: j['sku'] as String? ?? '',
        unitType: j['unitType'] as String? ?? '',
        quantity: (j['netQuantity'] as num?)?.toDouble() ??
            (j['quantity'] as num?)?.toDouble() ??
            (j['grossQuantity'] as num?)?.toDouble() ??
            0,
        netAmount: (j['netAmount'] as num?)?.toDouble() ?? 0,
        repository: j['repositoryName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'product': product,
        'sku': sku,
        'unitType': unitType,
        'quantity': quantity,
        'netAmount': netAmount,
        'repository': repository,
      };

  factory GithubUsageItem.fromJson(Map<String, dynamic> j) => GithubUsageItem(
        product: j['product'] as String? ?? '',
        sku: j['sku'] as String? ?? '',
        unitType: j['unitType'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toDouble() ?? 0,
        netAmount: (j['netAmount'] as num?)?.toDouble() ?? 0,
        repository: j['repository'] as String?,
      );
}

/// Everything the billing endpoints gave up, and how much of it was missing.
///
/// `available` is deliberately separate from "all zeroes": a token without
/// the billing scope and an account that genuinely spent nothing both come
/// back as zero, and the UI must not tell the second user their token is
/// wrong.
class GithubBilling {
  const GithubBilling({
    required this.available,
    required this.unavailableReason,
    required this.minutesUsed,
    required this.minutesIncluded,
    required this.paidMinutesUsed,
    required this.minutesBreakdown,
    required this.storageGbUsed,
    required this.bandwidthGbUsed,
    required this.bandwidthGbIncluded,
    required this.daysLeftInCycle,
    required this.usageItems,
  });

  final bool available;

  /// Why the numbers are missing, in words the user can act on.
  final String? unavailableReason;

  final double minutesUsed;

  /// 0 when GitHub did not report an allowance — draw the raw number, not a
  /// bar against a made-up denominator.
  final double minutesIncluded;
  final double paidMinutesUsed;

  /// Minutes per runner OS, e.g. `{UBUNTU: 120, WINDOWS: 44}`.
  final Map<String, double> minutesBreakdown;

  final double storageGbUsed;
  final double bandwidthGbUsed;
  final double bandwidthGbIncluded;
  final int daysLeftInCycle;

  final List<GithubUsageItem> usageItems;

  static const empty = GithubBilling(
    available: false,
    unavailableReason: null,
    minutesUsed: 0,
    minutesIncluded: 0,
    paidMinutesUsed: 0,
    minutesBreakdown: {},
    storageGbUsed: 0,
    bandwidthGbUsed: 0,
    bandwidthGbIncluded: 0,
    daysLeftInCycle: 0,
    usageItems: [],
  );

  /// Usage lines that belong to Copilot, whatever GitHub is calling the
  /// unit this quarter.
  List<GithubUsageItem> get copilotItems => usageItems
      .where((i) => i.product.toLowerCase().contains('copilot'))
      .toList();

  double get copilotQuantity =>
      copilotItems.fold(0.0, (sum, i) => sum + i.quantity);

  double get copilotSpend =>
      copilotItems.fold(0.0, (sum, i) => sum + i.netAmount);

  /// The unit Copilot is billed in right now, taken from the data rather
  /// than assumed — "AI Credit", "premium request", and whatever comes next
  /// all label themselves correctly.
  String get copilotUnit {
    for (final item in copilotItems) {
      if (item.unitType.isNotEmpty) return item.unitType;
      if (item.sku.isNotEmpty) return item.sku;
    }
    return 'requests';
  }

  double get totalSpend => usageItems.fold(0.0, (sum, i) => sum + i.netAmount);

  /// Actions-attributable usage lines, for the compute breakdown.
  List<GithubUsageItem> get actionsItems => usageItems
      .where((i) => i.product.toLowerCase().contains('action'))
      .toList();

  List<GithubUsageItem> get storageItems => usageItems
      .where((i) =>
          i.product.toLowerCase().contains('storage') ||
          i.product.toLowerCase().contains('package'))
      .toList();

  GithubBilling copyWith({
    bool? available,
    String? unavailableReason,
    double? minutesUsed,
    double? minutesIncluded,
    double? paidMinutesUsed,
    Map<String, double>? minutesBreakdown,
    double? storageGbUsed,
    double? bandwidthGbUsed,
    double? bandwidthGbIncluded,
    int? daysLeftInCycle,
    List<GithubUsageItem>? usageItems,
  }) =>
      GithubBilling(
        available: available ?? this.available,
        unavailableReason: unavailableReason ?? this.unavailableReason,
        minutesUsed: minutesUsed ?? this.minutesUsed,
        minutesIncluded: minutesIncluded ?? this.minutesIncluded,
        paidMinutesUsed: paidMinutesUsed ?? this.paidMinutesUsed,
        minutesBreakdown: minutesBreakdown ?? this.minutesBreakdown,
        storageGbUsed: storageGbUsed ?? this.storageGbUsed,
        bandwidthGbUsed: bandwidthGbUsed ?? this.bandwidthGbUsed,
        bandwidthGbIncluded: bandwidthGbIncluded ?? this.bandwidthGbIncluded,
        daysLeftInCycle: daysLeftInCycle ?? this.daysLeftInCycle,
        usageItems: usageItems ?? this.usageItems,
      );

  Map<String, dynamic> toJson() => {
        'available': available,
        'unavailableReason': unavailableReason,
        'minutesUsed': minutesUsed,
        'minutesIncluded': minutesIncluded,
        'paidMinutesUsed': paidMinutesUsed,
        'minutesBreakdown': minutesBreakdown,
        'storageGbUsed': storageGbUsed,
        'bandwidthGbUsed': bandwidthGbUsed,
        'bandwidthGbIncluded': bandwidthGbIncluded,
        'daysLeftInCycle': daysLeftInCycle,
        'usageItems': usageItems.map((i) => i.toJson()).toList(),
      };

  factory GithubBilling.fromJson(Map<String, dynamic> j) => GithubBilling(
        available: j['available'] as bool? ?? false,
        unavailableReason: j['unavailableReason'] as String?,
        minutesUsed: (j['minutesUsed'] as num?)?.toDouble() ?? 0,
        minutesIncluded: (j['minutesIncluded'] as num?)?.toDouble() ?? 0,
        paidMinutesUsed: (j['paidMinutesUsed'] as num?)?.toDouble() ?? 0,
        minutesBreakdown: {
          for (final e in (j['minutesBreakdown'] as Map<String, dynamic>? ?? {})
              .entries)
            e.key: (e.value as num).toDouble(),
        },
        storageGbUsed: (j['storageGbUsed'] as num?)?.toDouble() ?? 0,
        bandwidthGbUsed: (j['bandwidthGbUsed'] as num?)?.toDouble() ?? 0,
        bandwidthGbIncluded: (j['bandwidthGbIncluded'] as num?)?.toDouble() ?? 0,
        daysLeftInCycle: (j['daysLeftInCycle'] as num?)?.toInt() ?? 0,
        usageItems: (j['usageItems'] as List<dynamic>? ?? [])
            .map((e) => GithubUsageItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// The whole GitHub picture, as one cacheable snapshot.
class GithubSnapshot {
  const GithubSnapshot({
    required this.profile,
    required this.repos,
    required this.contributions,
    required this.issues,
    required this.issueTotals,
    required this.runs,
    required this.billing,
    required this.fetchedAt,
  });

  final GithubProfile? profile;
  final List<GithubRepo> repos;
  final GithubContributions contributions;
  final List<GithubIssue> issues;
  final GithubIssueTotals issueTotals;
  final List<GithubWorkflowRun> runs;
  final GithubBilling billing;
  final DateTime fetchedAt;

  static final empty = GithubSnapshot(
    profile: null,
    repos: const [],
    contributions: GithubContributions.empty,
    issues: const [],
    issueTotals: GithubIssueTotals.empty,
    runs: const [],
    billing: GithubBilling.empty,
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  bool get isEmpty => profile == null;

  int get totalStars => repos.fold(0, (sum, r) => sum + r.stars);
  int get totalForks => repos.fold(0, (sum, r) => sum + r.forks);
  int get totalDownloads => repos.fold(0, (sum, r) => sum + r.downloads);
  int get totalWatchers => repos.fold(0, (sum, r) => sum + r.watchers);

  /// Repository size across the account, in MB.
  double get totalSizeMb =>
      repos.fold(0.0, (sum, r) => sum + r.sizeKb) / 1024.0;

  /// Bytes-on-disk is not the same thing as "languages used", so this is a
  /// repository count per language rather than a byte share — cheap, and
  /// honest about what it measures.
  Map<String, int> get languageCounts {
    final counts = <String, int>{};
    for (final repo in repos) {
      final lang = repo.language;
      if (lang == null || lang.isEmpty) continue;
      counts[lang] = (counts[lang] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, dynamic> toJson() => {
        'profile': profile?.toJson(),
        'repos': repos.map((r) => r.toJson()).toList(),
        'contributions': contributions.toJson(),
        'issues': issues.map((i) => i.toJson()).toList(),
        'issueTotals': issueTotals.toJson(),
        'runs': runs.map((r) => r.toJson()).toList(),
        'billing': billing.toJson(),
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory GithubSnapshot.fromJson(Map<String, dynamic> j) => GithubSnapshot(
        profile: j['profile'] == null
            ? null
            : GithubProfile.fromJson(j['profile'] as Map<String, dynamic>),
        repos: (j['repos'] as List<dynamic>? ?? [])
            .map((e) => GithubRepo.fromJson(e as Map<String, dynamic>))
            .toList(),
        contributions: j['contributions'] == null
            ? GithubContributions.empty
            : GithubContributions.fromJson(
                j['contributions'] as Map<String, dynamic>),
        issues: (j['issues'] as List<dynamic>? ?? [])
            .map((e) => GithubIssue.fromJson(e as Map<String, dynamic>))
            .toList(),
        issueTotals: j['issueTotals'] == null
            ? GithubIssueTotals.empty
            : GithubIssueTotals.fromJson(
                j['issueTotals'] as Map<String, dynamic>),
        runs: (j['runs'] as List<dynamic>? ?? [])
            .map((e) => GithubWorkflowRun.fromJson(e as Map<String, dynamic>))
            .toList(),
        billing: j['billing'] == null
            ? GithubBilling.empty
            : GithubBilling.fromJson(j['billing'] as Map<String, dynamic>),
        fetchedAt: DateTime.tryParse(j['fetchedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
