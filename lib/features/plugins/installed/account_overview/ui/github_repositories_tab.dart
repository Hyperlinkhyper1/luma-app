import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../account_overview_scope.dart';
import '../github_models.dart';
import 'account_shared.dart';

/// How the repository list is ordered.
enum _RepoSort {
  updated('Recently pushed'),
  stars('Stars'),
  downloads('Downloads'),
  name('Name'),
  size('Size');

  const _RepoSort(this.label);
  final String label;
}

/// Which repositories are in view.
enum _RepoFilter {
  all('All'),
  sources('Sources'),
  forks('Forks'),
  private('Private'),
  archived('Archived');

  const _RepoFilter(this.label);
  final String label;
}

/// Every repository the account owns, as GitHub's own repository list reads:
/// name, description, then the language dot and counts on one meta line.
class GithubRepositoriesTab extends StatefulWidget {
  const GithubRepositoriesTab({super.key});

  @override
  State<GithubRepositoriesTab> createState() => _GithubRepositoriesTabState();
}

class _GithubRepositoriesTabState extends State<GithubRepositoriesTab> {
  final _controller = TextEditingController();
  String _query = '';
  _RepoSort _sort = _RepoSort.updated;
  _RepoFilter _filter = _RepoFilter.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<GithubRepo> _visible(List<GithubRepo> repos) {
    final query = _query.trim().toLowerCase();
    final filtered = repos.where((repo) {
      final matchesFilter = switch (_filter) {
        _RepoFilter.all => true,
        _RepoFilter.sources => !repo.isFork,
        _RepoFilter.forks => repo.isFork,
        _RepoFilter.private => repo.isPrivate,
        _RepoFilter.archived => repo.isArchived,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return repo.name.toLowerCase().contains(query) ||
          (repo.description?.toLowerCase().contains(query) ?? false) ||
          (repo.language?.toLowerCase().contains(query) ?? false);
    }).toList();

    filtered.sort(switch (_sort) {
      _RepoSort.updated => (a, b) {
          final at = a.pushedAt, bt = b.pushedAt;
          if (at == null && bt == null) return 0;
          if (at == null) return 1;
          if (bt == null) return -1;
          return bt.compareTo(at);
        },
      _RepoSort.stars => (a, b) => b.stars.compareTo(a.stars),
      _RepoSort.downloads => (a, b) => b.downloads.compareTo(a.downloads),
      _RepoSort.name => (a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      _RepoSort.size => (a, b) => b.sizeKb.compareTo(a.sizeKb),
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final snapshot = AccountOverviewScope.of(context).snapshot;
    final visible = _visible(snapshot.repos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          controller: _controller,
          sort: _sort,
          filter: _filter,
          onQuery: (value) => setState(() => _query = value),
          onSort: (value) => setState(() => _sort = value),
          onFilter: (value) => setState(() => _filter = value),
        ),
        Expanded(
          child: snapshot.repos.isEmpty
              ? const LumaEmptyState(
                  icon: Icons.folder_off_outlined,
                  title: 'No repositories',
                  subtitle: 'Refresh once your account has repositories, or '
                      'widen the token scope to include private ones.',
                )
              : visible.isEmpty
                  ? LumaEmptyState(
                      icon: Icons.search_off_rounded,
                      title: _query.isEmpty
                          ? 'Nothing matches this filter'
                          : 'No repositories match "$_query"',
                      subtitle: 'Try a different filter or a shorter search.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      itemCount: visible.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RepoCard(repo: visible[index]),
                      ),
                    ),
        ),
        if (visible.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: luma.surface,
              border: Border(top: BorderSide(color: luma.border)),
            ),
            child: Row(
              children: [
                Text(
                  '${visible.length} of ${snapshot.repos.length} repositories',
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
                const Spacer(),
                AccountMetaCount(
                  icon: Icons.star_rounded,
                  value: formatCount(
                      visible.fold(0, (sum, r) => sum + r.stars)),
                  semanticLabel: 'Stars in view',
                  color: luma.warning,
                ),
                const SizedBox(width: 14),
                AccountMetaCount(
                  icon: Icons.download_rounded,
                  value: formatCount(
                      visible.fold(0, (sum, r) => sum + r.downloads)),
                  semanticLabel: 'Downloads in view',
                  color: luma.success,
                ),
                const SizedBox(width: 14),
                AccountMetaCount(
                  icon: Icons.sd_storage_outlined,
                  value: formatBytesFromKb(
                      visible.fold(0, (sum, r) => sum + r.sizeKb)),
                  semanticLabel: 'Size in view',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.sort,
    required this.filter,
    required this.onQuery,
    required this.onSort,
    required this.onFilter,
  });

  final TextEditingController controller;
  final _RepoSort sort;
  final _RepoFilter filter;
  final ValueChanged<String> onQuery;
  final ValueChanged<_RepoSort> onSort;
  final ValueChanged<_RepoFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: controller,
                    onChanged: onQuery,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Find a repository',
                      hintStyle:
                          TextStyle(color: luma.textMuted, fontSize: 13),
                      prefixIcon:
                          Icon(Icons.search_rounded, size: 18, color: luma.textMuted),
                      filled: true,
                      fillColor: luma.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: luma.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: luma.accent, width: 2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _SortMenu(sort: sort, onSort: onSort),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: LumaSegmentedTabs(
              tabs: [for (final f in _RepoFilter.values) f.label],
              selectedIndex: filter.index,
              onSelect: (index) => onFilter(_RepoFilter.values[index]),
              scrollable: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onSort});

  final _RepoSort sort;
  final ValueChanged<_RepoSort> onSort;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return PopupMenuButton<_RepoSort>(
      tooltip: 'Sort repositories',
      initialValue: sort,
      color: luma.surface,
      onSelected: onSort,
      itemBuilder: (context) => [
        for (final option in _RepoSort.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                Icon(
                  option == sort
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: option == sort ? luma.accent : luma.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  option.label,
                  style: TextStyle(color: luma.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: luma.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: luma.border),
        ),
        child: Row(
          children: [
            Icon(Icons.swap_vert_rounded, size: 16, color: luma.textSecondary),
            const SizedBox(width: 8),
            Text(
              sort.label,
              style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepoCard extends StatelessWidget {
  const _RepoCard({required this.repo});

  final GithubRepo repo;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;

    return Material(
      color: luma.surface,
      borderRadius: decor.cardBorderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openExternal(repo.htmlUrl),
        hoverColor: luma.surfaceHover,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: decor.cardBorderRadius,
            border: Border.all(color: luma.border, width: decor.borderWidth),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          repo.name,
                          style: TextStyle(
                            color: luma.accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AccountBadge(
                          label: repo.isPrivate ? 'Private' : 'Public',
                          icon: repo.isPrivate
                              ? Icons.lock_outline_rounded
                              : Icons.public_rounded,
                        ),
                        if (repo.isFork)
                          const AccountBadge(
                            label: 'Fork',
                            icon: Icons.call_split_rounded,
                          ),
                        if (repo.isArchived)
                          AccountBadge(
                            label: 'Archived',
                            icon: Icons.inventory_2_outlined,
                            color: luma.warning,
                            filled: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.open_in_new_rounded,
                      size: 14, color: luma.textMuted),
                ],
              ),
              if (repo.description != null && repo.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  repo.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (repo.language != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: languageColor(repo.language!),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          repo.language!,
                          style: TextStyle(
                            color: luma.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  AccountMetaCount(
                    icon: Icons.star_outline_rounded,
                    value: formatCompact(repo.stars),
                    semanticLabel: '${repo.stars} stars',
                  ),
                  AccountMetaCount(
                    icon: Icons.call_split_rounded,
                    value: formatCompact(repo.forks),
                    semanticLabel: '${repo.forks} forks',
                  ),
                  AccountMetaCount(
                    icon: Icons.adjust_rounded,
                    value: formatCompact(repo.openIssues),
                    semanticLabel: '${repo.openIssues} open issues and pull '
                        'requests',
                  ),
                  if (repo.downloads > 0)
                    AccountMetaCount(
                      icon: Icons.download_outlined,
                      value: formatCompact(repo.downloads),
                      semanticLabel: '${repo.downloads} release downloads',
                      color: luma.success,
                    ),
                  AccountMetaCount(
                    icon: Icons.sd_storage_outlined,
                    value: formatBytesFromKb(repo.sizeKb),
                    semanticLabel: 'Size ${formatBytesFromKb(repo.sizeKb)}',
                  ),
                  Text(
                    'Updated ${formatRelative(repo.pushedAt)}',
                    style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
