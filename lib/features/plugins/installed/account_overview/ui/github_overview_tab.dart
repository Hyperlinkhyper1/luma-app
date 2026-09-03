import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../account_overview_scope.dart';
import '../github_models.dart';
import 'account_shared.dart';

/// The GitHub landing view: who you are, the headline counts, the
/// contribution graph, and the shortlist of repositories and runs.
class GithubOverviewTab extends StatelessWidget {
  const GithubOverviewTab({super.key, required this.onOpenSection});

  /// Lets the "view all" links hand the user to the matching sidebar
  /// section rather than opening a dead end.
  final void Function(String sectionId) onOpenSection;

  @override
  Widget build(BuildContext context) {
    final repository = AccountOverviewScope.of(context);
    final snapshot = repository.snapshot;
    final profile = snapshot.profile;
    final luma = context.luma;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        if (profile != null) _ProfileHeader(profile: profile),
        const SizedBox(height: 18),
        _StatGrid(snapshot: snapshot, onOpenSection: onOpenSection),
        const SizedBox(height: 18),
        AccountPanel(
          title: 'Contributions',
          icon: Icons.grid_view_rounded,
          subtitle: snapshot.contributions.calendarTotal > 0
              ? '${formatCount(snapshot.contributions.calendarTotal)} in the '
                  'last year'
              : 'The last year of activity',
          trailing: _ContributionSummary(
            contributions: snapshot.contributions,
          ),
          child: GithubContributionGraph(
            contributions: snapshot.contributions,
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final panels = [
              _TopRepositories(
                repos: snapshot.repos,
                onViewAll: () => onOpenSection('repositories'),
              ),
              _LanguageBreakdown(counts: snapshot.languageCounts),
            ];
            // Side by side once there is room for two readable columns;
            // stacked below that.
            if (constraints.maxWidth < 760) {
              return Column(
                children: [
                  panels[0],
                  const SizedBox(height: 18),
                  panels[1],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: panels[0]),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: panels[1]),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _RecentRuns(
          runs: snapshot.runs,
          onViewAll: () => onOpenSection('actions'),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            snapshot.fetchedAt.millisecondsSinceEpoch == 0
                ? 'Not refreshed yet'
                : 'Updated ${formatRelative(snapshot.fetchedAt)}',
            style: TextStyle(color: luma.textMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final GithubProfile profile;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: decor.cardBorderRadius,
        border: Border.all(color: luma.border, width: decor.borderWidth),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final avatar = _Avatar(url: profile.avatarUrl, login: profile.login);
          final identity = Column(
            crossAxisAlignment:
                narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.displayName,
                textAlign: narrow ? TextAlign.center : TextAlign.start,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profile.login,
                style: TextStyle(color: luma.textSecondary, fontSize: 14),
              ),
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  profile.bio!,
                  textAlign: narrow ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                alignment:
                    narrow ? WrapAlignment.center : WrapAlignment.start,
                children: [
                  AccountMetaCount(
                    icon: Icons.people_outline_rounded,
                    value: '${formatCount(profile.followers)} followers',
                    semanticLabel: '${profile.followers} followers',
                  ),
                  AccountMetaCount(
                    icon: Icons.person_add_alt_outlined,
                    value: '${formatCount(profile.following)} following',
                    semanticLabel: '${profile.following} following',
                  ),
                  if (profile.company != null && profile.company!.isNotEmpty)
                    AccountMetaCount(
                      icon: Icons.business_outlined,
                      value: profile.company!,
                      semanticLabel: 'Company ${profile.company}',
                    ),
                  if (profile.location != null && profile.location!.isNotEmpty)
                    AccountMetaCount(
                      icon: Icons.place_outlined,
                      value: profile.location!,
                      semanticLabel: 'Location ${profile.location}',
                    ),
                  if (profile.createdAt != null)
                    AccountMetaCount(
                      icon: Icons.cake_outlined,
                      value: 'Joined ${formatDate(profile.createdAt!)}',
                      semanticLabel:
                          'Joined ${formatDate(profile.createdAt!)}',
                    ),
                ],
              ),
            ],
          );

          final actions = Wrap(
            spacing: 4,
            alignment: narrow ? WrapAlignment.center : WrapAlignment.end,
            children: [
              if (profile.planName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12, right: 6),
                  child: AccountBadge(
                    label: profile.planName!.toUpperCase(),
                    color: luma.accent,
                    filled: true,
                    icon: Icons.workspace_premium_outlined,
                  ),
                ),
              AccountLinkButton(
                label: 'Profile',
                icon: Icons.open_in_new_rounded,
                onTap: () => openExternal(profile.htmlUrl),
              ),
            ],
          );

          if (narrow) {
            return Column(
              children: [
                avatar,
                const SizedBox(height: 14),
                identity,
                const SizedBox(height: 6),
                actions,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              avatar,
              const SizedBox(width: 18),
              Expanded(child: identity),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }
}

/// The avatar, with the account's initial standing in while the image loads
/// or if it never does — an offline launch should not leave a broken box.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.login});

  final String url;
  final String login;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final fallback = Container(
      width: 74,
      height: 74,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: luma.accentSubtle,
        shape: BoxShape.circle,
      ),
      child: Text(
        login.isEmpty ? '?' : login[0].toUpperCase(),
        style: TextStyle(
          color: luma.accent,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (url.isEmpty) return fallback;

    return Semantics(
      label: '$login avatar',
      image: true,
      child: ClipOval(
        child: Image.network(
          url,
          width: 74,
          height: 74,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
        ),
      ),
    );
  }
}

class _ContributionSummary extends StatelessWidget {
  const _ContributionSummary({required this.contributions});

  final GithubContributions contributions;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (contributions.days.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      children: [
        AccountMetaCount(
          icon: Icons.local_fire_department_outlined,
          value: '${contributions.currentStreak}d streak',
          semanticLabel:
              'Current streak ${contributions.currentStreak} days',
          color: contributions.currentStreak > 0 ? luma.warning : null,
        ),
        AccountMetaCount(
          icon: Icons.emoji_events_outlined,
          value: '${contributions.longestStreak}d best',
          semanticLabel: 'Longest streak ${contributions.longestStreak} days',
        ),
      ],
    );
  }
}

/// The headline counts. A responsive grid rather than a fixed row, so the
/// tiles reflow instead of squeezing on a phone.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.snapshot, required this.onOpenSection});

  final GithubSnapshot snapshot;
  final void Function(String sectionId) onOpenSection;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final contributions = snapshot.contributions;
    final totals = snapshot.issueTotals;

    final tiles = <Widget>[
      AccountStatTile(
        icon: Icons.commit_rounded,
        label: 'Commits',
        value: formatCompact(contributions.totalCommits),
        caption: contributions.restricted > 0
            ? '+${formatCount(contributions.restricted)} private'
            : 'in the last year',
      ),
      AccountStatTile(
        icon: Icons.star_outline_rounded,
        label: 'Stars earned',
        value: formatCompact(snapshot.totalStars),
        caption: 'across ${snapshot.repos.length} repos',
        tint: luma.warning,
        onTap: () => onOpenSection('repositories'),
      ),
      AccountStatTile(
        icon: Icons.folder_outlined,
        label: 'Repositories',
        value: formatCount(snapshot.repos.length),
        caption: snapshot.profile == null
            ? null
            : '${snapshot.profile!.privateRepos} private',
        onTap: () => onOpenSection('repositories'),
      ),
      AccountStatTile(
        icon: Icons.download_outlined,
        label: 'Downloads',
        value: formatCompact(snapshot.totalDownloads),
        caption: 'release assets',
        tint: luma.success,
        onTap: () => onOpenSection('repositories'),
      ),
      AccountStatTile(
        icon: Icons.adjust_rounded,
        label: 'Open issues',
        value: formatCount(totals.openIssues),
        caption: '${formatCount(totals.closedIssues)} closed',
        onTap: () => onOpenSection('issues'),
      ),
      AccountStatTile(
        icon: Icons.merge_rounded,
        label: 'Merged PRs',
        value: formatCount(totals.mergedPrs),
        caption: '${formatCount(totals.openPrs)} open',
        tint: luma.accent,
        onTap: () => onOpenSection('issues'),
      ),
      AccountStatTile(
        icon: Icons.call_split_rounded,
        label: 'Forks',
        value: formatCompact(snapshot.totalForks),
        caption: 'of your repos',
        onTap: () => onOpenSection('repositories'),
      ),
      AccountStatTile(
        icon: Icons.play_circle_outline_rounded,
        label: 'Workflow runs',
        value: formatCount(snapshot.runs.length),
        caption: 'recent',
        onTap: () => onOpenSection('actions'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Aim for ~190px columns and let the count fall out of the width,
        // so the grid works from a 375px phone to a wide desktop.
        final columns = (constraints.maxWidth / 190).floor().clamp(2, 4);
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _TopRepositories extends StatelessWidget {
  const _TopRepositories({required this.repos, required this.onViewAll});

  final List<GithubRepo> repos;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final top = [...repos]..sort((a, b) => b.stars.compareTo(a.stars));
    final visible = top.take(6).toList();

    return AccountPanel(
      title: 'Top repositories',
      icon: Icons.star_outline_rounded,
      subtitle: 'By stars',
      trailing: repos.length > 6
          ? AccountLinkButton(label: 'View all', onTap: onViewAll)
          : null,
      padding: EdgeInsets.zero,
      child: visible.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No repositories yet.',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < visible.length; i++)
                  _CompactRepoRow(
                    repo: visible[i],
                    isLast: i == visible.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _CompactRepoRow extends StatelessWidget {
  const _CompactRepoRow({required this.repo, required this.isLast});

  final GithubRepo repo;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openExternal(repo.htmlUrl),
        hoverColor: luma.surfaceHover,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(bottom: BorderSide(color: luma.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      repo.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (repo.language != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: languageColor(repo.language!),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            repo.language!,
                            style: TextStyle(
                              color: luma.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AccountMetaCount(
                icon: Icons.star_rounded,
                value: formatCompact(repo.stars),
                semanticLabel: '${repo.stars} stars',
                color: luma.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Repository count per language, as a stacked proportion bar plus a legend.
///
/// The bar alone would be colour-only information, so every language is
/// named and counted underneath it.
class _LanguageBreakdown extends StatelessWidget {
  const _LanguageBreakdown({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0, (sum, e) => sum + e.value);
    final visible = entries.take(6).toList();

    return AccountPanel(
      title: 'Languages',
      icon: Icons.code_rounded,
      subtitle: 'By repository count',
      child: total == 0
          ? Text(
              'No languages detected yet.',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 9,
                    child: Row(
                      children: [
                        for (final entry in visible)
                          Expanded(
                            flex: entry.value,
                            child: ColoredBox(
                              color: languageColor(entry.key),
                            ),
                          ),
                        if (visible.length < entries.length)
                          Expanded(
                            flex: total -
                                visible.fold(0, (sum, e) => sum + e.value),
                            child: ColoredBox(color: luma.border),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                for (final entry in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: languageColor(entry.key),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            entry.key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: luma.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.value} · '
                          '${(entry.value / total * 100).round()}%',
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 11,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RecentRuns extends StatelessWidget {
  const _RecentRuns({required this.runs, required this.onViewAll});

  final List<GithubWorkflowRun> runs;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final visible = runs.take(5).toList();
    return AccountPanel(
      title: 'Latest workflow runs',
      icon: Icons.play_circle_outline_rounded,
      trailing: runs.isEmpty
          ? null
          : AccountLinkButton(label: 'View all', onTap: onViewAll),
      padding: EdgeInsets.zero,
      child: visible.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No workflow runs found in your most recently pushed '
                'repositories.',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < visible.length; i++)
                  GithubRunRow(
                    run: visible[i],
                    isLast: i == visible.length - 1,
                  ),
              ],
            ),
    );
  }
}

/// One workflow run. Status is an icon *and* a colour, so a red-green
/// distinction is never the only signal.
class GithubRunRow extends StatelessWidget {
  const GithubRunRow({super.key, required this.run, required this.isLast});

  final GithubWorkflowRun run;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final (icon, color, statusLabel) = runStatusVisual(context, run);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openExternal(run.htmlUrl),
        hoverColor: luma.surfaceHover,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border:
                isLast ? null : Border(bottom: BorderSide(color: luma.border)),
          ),
          child: Row(
            children: [
              Semantics(
                label: statusLabel,
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      run.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${run.repo}  ·  ${run.branch}  ·  '
                      '${formatRelative(run.startedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (run.duration != null)
                Text(
                  formatDuration(run.duration!),
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 11.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon, colour and spoken label for a run's state, in one place so the
/// overview and the Actions tab cannot drift apart.
(IconData, Color, String) runStatusVisual(
    BuildContext context, GithubWorkflowRun run) {
  final luma = context.luma;
  if (run.isRunning) {
    return (Icons.circle_outlined, luma.warning, 'In progress');
  }
  return switch (run.conclusion) {
    'success' => (Icons.check_circle_rounded, luma.success, 'Succeeded'),
    'failure' || 'timed_out' => (Icons.cancel_rounded, luma.danger, 'Failed'),
    'cancelled' => (Icons.do_not_disturb_on_rounded, luma.textMuted, 'Cancelled'),
    'skipped' => (Icons.remove_circle_outline_rounded, luma.textMuted, 'Skipped'),
    _ => (Icons.help_outline_rounded, luma.textMuted, 'Unknown'),
  };
}
