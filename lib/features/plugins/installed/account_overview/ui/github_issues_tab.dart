import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../account_overview_scope.dart';
import '../github_models.dart';
import 'account_shared.dart';

enum _IssueFilter {
  all,
  openIssues,
  openPrs,
  merged,
  closed;

  String label(L t) => switch (this) {
        _IssueFilter.all => t.githubIssuesFilterAll,
        _IssueFilter.openIssues => t.githubOpenIssues,
        _IssueFilter.openPrs => t.githubOpenPrs,
        _IssueFilter.merged => t.githubIssuesFilterMerged,
        _IssueFilter.closed => t.githubIssuesFilterClosed,
      };
}

/// Issues and pull requests involving the account, with the totals up top.
class GithubIssuesTab extends StatefulWidget {
  const GithubIssuesTab({super.key});

  @override
  State<GithubIssuesTab> createState() => _GithubIssuesTabState();
}

class _GithubIssuesTabState extends State<GithubIssuesTab> {
  _IssueFilter _filter = _IssueFilter.all;

  List<GithubIssue> _visible(List<GithubIssue> issues) =>
      issues.where((issue) => switch (_filter) {
            _IssueFilter.all => true,
            _IssueFilter.openIssues => !issue.isPullRequest && issue.isOpen,
            _IssueFilter.openPrs => issue.isPullRequest && issue.isOpen,
            _IssueFilter.merged => issue.merged,
            _IssueFilter.closed => !issue.isOpen,
          }).toList();

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final snapshot = AccountOverviewScope.of(context).snapshot;
    final totals = snapshot.issueTotals;
    final visible = _visible(snapshot.issues);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 200).floor().clamp(2, 4);
              const spacing = 12.0;
              final width =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              final tiles = [
                AccountStatTile(
                  icon: Icons.adjust_rounded,
                  label: t.githubOpenIssues,
                  value: formatCount(totals.openIssues),
                  caption: t.githubCaptionYouOpened,
                  tint: luma.success,
                ),
                AccountStatTile(
                  icon: Icons.task_alt_rounded,
                  label: t.githubClosedIssues,
                  value: formatCount(totals.closedIssues),
                  caption: t.githubCaptionYouOpened,
                ),
                AccountStatTile(
                  icon: Icons.merge_type_rounded,
                  label: t.githubOpenPrs,
                  value: formatCount(totals.openPrs),
                  caption: t.githubCaptionAwaitingReview,
                  tint: luma.success,
                ),
                AccountStatTile(
                  icon: Icons.merge_rounded,
                  label: t.githubMergedPrs,
                  value: formatCount(totals.mergedPrs),
                  caption: t.githubCaptionAllTime,
                  tint: luma.accent,
                ),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final tile in tiles)
                    SizedBox(width: width, child: tile),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: LumaSegmentedTabs(
              tabs: [for (final f in _IssueFilter.values) f.label(t)],
              selectedIndex: _filter.index,
              onSelect: (index) =>
                  setState(() => _filter = _IssueFilter.values[index]),
              scrollable: true,
            ),
          ),
        ),
        Expanded(
          child: snapshot.issues.isEmpty
              ? LumaEmptyState(
                  icon: Icons.inbox_outlined,
                  title: t.githubIssuesEmptyTitle,
                  subtitle: t.githubIssuesEmptySubtitle,
                )
              : visible.isEmpty
                  ? LumaEmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: t.githubIssuesNothingInFilter(_filter.label(t)),
                      subtitle: t.githubIssuesPickAnotherFilter,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      itemCount: visible.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _IssueRow(issue: visible[index]),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue});

  final GithubIssue issue;

  /// GitHub's four states, each with its own glyph so the colour is never
  /// doing the work alone.
  (IconData, Color, String) _visual(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    if (issue.isPullRequest) {
      if (issue.merged) {
        return (Icons.merge_rounded, luma.accent, t.githubStatusMergedPr);
      }
      if (!issue.isOpen) {
        return (Icons.block_rounded, luma.danger, t.githubStatusClosedPr);
      }
      if (issue.isDraft) {
        return (
          Icons.merge_type_rounded,
          luma.textMuted,
          t.githubStatusDraftPr
        );
      }
      return (Icons.merge_type_rounded, luma.success, t.githubStatusOpenPr);
    }
    return issue.isOpen
        ? (Icons.adjust_rounded, luma.success, t.githubStatusOpenIssue)
        : (Icons.task_alt_rounded, luma.accent, t.githubStatusClosedIssue);
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final decor = context.lumaDecor;
    final (icon, color, statusLabel) = _visual(context);

    return Material(
      color: luma.surface,
      borderRadius: decor.cardBorderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openExternal(issue.htmlUrl),
        hoverColor: luma.surfaceHover,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: decor.cardBorderRadius,
            border: Border.all(color: luma.border, width: decor.borderWidth),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Semantics(
                  label: statusLabel,
                  child: Icon(icon, size: 17, color: color),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      issue.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      t.githubIssueRowMeta(
                        issue.repo,
                        '${issue.number}',
                        formatRelative(issue.updatedAt),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (issue.comments > 0) ...[
                const SizedBox(width: 10),
                AccountMetaCount(
                  icon: Icons.mode_comment_outlined,
                  value: formatCount(issue.comments),
                  semanticLabel: t.githubIssueCommentsSemantic(issue.comments),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
