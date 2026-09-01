import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'account_overview_repository.dart';
import 'account_overview_scope.dart';
import 'mc_content_repository.dart';
import 'mc_content_scope.dart';
import 'ui/account_shared.dart';
import 'ui/github_actions_tab.dart';
import 'ui/github_connect_dialog.dart';
import 'ui/github_issues_tab.dart';
import 'ui/github_overview_tab.dart';
import 'ui/github_repositories_tab.dart';
import 'ui/github_usage_tab.dart';
import 'ui/mc_content_tab.dart';
import 'ui/youtube_analytics_tab.dart';
import 'ui/youtube_connect_dialog.dart';
import 'ui/youtube_overview_tab.dart';
import 'ui/youtube_videos_tab.dart';
import 'youtube_repository.dart';
import 'youtube_scope.dart';

/// A service the sidebar groups its sections under.
///
/// The rail is a list of accounts, not a flat list of pages: each service
/// carries its own credentials, its own connected state and its own sections,
/// so adding the next one is a new value here rather than a new rail.
enum AccountService {
  github('GitHub', Icons.hub_rounded),
  minecraft('Minecraft', Icons.widgets_rounded),
  youtube('YouTube', Icons.smart_display_rounded);

  const AccountService(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The plugin's sections, in sidebar order, grouped by [service].
enum AccountSection {
  overview(
    service: AccountService.github,
    id: 'overview',
    icon: Icons.dashboard_outlined,
    label: 'Overview',
    blurb: 'Commits, stars, activity',
  ),
  repositories(
    service: AccountService.github,
    id: 'repositories',
    icon: Icons.folder_outlined,
    label: 'Repositories',
    blurb: 'Every repo you own',
  ),
  issues(
    service: AccountService.github,
    id: 'issues',
    icon: Icons.adjust_rounded,
    label: 'Issues & PRs',
    blurb: 'What is open on you',
  ),
  actions(
    service: AccountService.github,
    id: 'actions',
    icon: Icons.play_circle_outline_rounded,
    label: 'Actions',
    blurb: 'Workflow runs and health',
  ),
  usage(
    service: AccountService.github,
    id: 'usage',
    icon: Icons.data_usage_rounded,
    label: 'Usage',
    blurb: 'Copilot, storage, compute',
  ),
  mcContent(
    service: AccountService.minecraft,
    id: 'mc-content',
    icon: Icons.grid_view_rounded,
    label: 'MC Content',
    blurb: 'CurseForge, Modrinth, PMC',
  ),
  youtubeOverview(
    service: AccountService.youtube,
    id: 'youtube-overview',
    icon: Icons.dashboard_outlined,
    label: 'Overview',
    blurb: 'Subscribers, views, videos',
  ),
  youtubeVideos(
    service: AccountService.youtube,
    id: 'youtube-videos',
    icon: Icons.video_library_outlined,
    label: 'Videos',
    blurb: 'Every recent upload',
  ),
  youtubeAnalytics(
    service: AccountService.youtube,
    id: 'youtube-analytics',
    icon: Icons.insights_rounded,
    label: 'Analytics',
    blurb: 'Watch time, traffic, subscribers',
  );

  const AccountSection({
    required this.service,
    required this.id,
    required this.icon,
    required this.label,
    required this.blurb,
  });

  final AccountService service;

  /// Stable name used by cross-section links, so a rename of [label] cannot
  /// quietly break "view all".
  final String id;
  final IconData icon;
  final String label;

  /// One-line description, shown under the label while the rail is expanded
  /// and inside the tooltip while it is collapsed.
  final String blurb;
}

/// The Account Overview plugin's frame: a collapsible service sidebar on the
/// left and the selected section on the right, following the same shape as
/// Steam Tools so the two plugins navigate identically.
class AccountOverviewPage extends StatefulWidget {
  const AccountOverviewPage({super.key});

  @override
  State<AccountOverviewPage> createState() => _AccountOverviewPageState();
}

class _AccountOverviewPageState extends State<AccountOverviewPage> {
  AccountSection _section = AccountSection.overview;
  bool _collapsed = false;
  bool _started = false;

  /// The one service whose sections are currently shown under its heading —
  /// an accordion, not independent toggles, so picking a section in one
  /// service folds every other one away.
  late AccountService? _expandedService = _section.service;

  void _selectSection(AccountSection section) {
    setState(() {
      _section = section;
      _expandedService = section.service;
    });
  }

  void _toggleServiceExpanded(AccountService service) {
    setState(() {
      _expandedService = _expandedService == service ? null : service;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The scope is not readable from initState — this is the first frame
    // where the repository exists.
    if (_started) return;
    _started = true;
    AccountOverviewScope.of(context).load();
  }

  void _openSection(String id) {
    final target = AccountSection.values.firstWhere(
      (s) => s.id == id,
      orElse: () => AccountSection.overview,
    );
    _selectSection(target);
  }

  /// Names the platforms that are actually set up, so the rail says
  /// "Modrinth, PMC" rather than a bare "Connected".
  static String? _mcSubtitle(McContentRepository mc) {
    final credentials = mc.credentials;
    final names = [
      if (credentials.hasCurseforge) 'CurseForge',
      if (credentials.hasModrinth) 'Modrinth',
      if (credentials.hasPmc) 'PMC',
    ];
    return names.isEmpty ? null : names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = AccountOverviewScope.of(context);

    final mc = McContentScope.of(context);
    final youtube = YoutubeScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // On a phone an expanded rail would eat more than half the width, so
        // it collapses to icons on its own and the manual toggle steps aside
        // rather than offering a choice that never helps.
        final compact = constraints.maxWidth < 640;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionRail(
              selected: _section,
              collapsed: compact || _collapsed,
              showToggle: !compact,
              // Each service reports its own readiness: a GitHub token says
              // nothing about whether Modrinth is set up, and greying out
              // MC Content because GitHub is missing would be a lie.
              connectedServices: {
                AccountService.github: repository.connected,
                AccountService.minecraft: mc.configured,
                AccountService.youtube: youtube.connected,
              },
              subtitles: {
                AccountService.github: repository.credentials?.login,
                AccountService.minecraft: _mcSubtitle(mc),
                AccountService.youtube: youtube.credentials?.channelTitle,
              },
              expandedService: _expandedService,
              onSelect: _selectSection,
              onToggleCollapsed: () => setState(() => _collapsed = !_collapsed),
              onToggleServiceExpanded: _toggleServiceExpanded,
            ),
            Container(width: 1, color: luma.border),
            Expanded(
              child: _SectionBody(
                section: _section,
                onOpenSection: _openSection,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The entry point for a service — the section that carries its setup or
/// connect prompt, and so stays reachable before it is configured.
AccountSection _firstSectionOf(AccountService service) =>
    AccountSection.values.firstWhere((s) => s.service == service);

/// GitHub's sections, in the order the [IndexedStack] below builds them.
final _githubSections = [
  for (final section in AccountSection.values)
    if (section.service == AccountService.github) section,
];

/// YouTube's sections, in the order its [IndexedStack] builds them.
final _youtubeSections = [
  for (final section in AccountSection.values)
    if (section.service == AccountService.youtube) section,
];

/// Chooses between the connect screen, the loading state and the section.
class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section, required this.onOpenSection});

  final AccountSection section;
  final void Function(String sectionId) onOpenSection;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = AccountOverviewScope.of(context);

    // Minecraft carries its own credentials and its own empty state, so it
    // bypasses the GitHub gate entirely rather than hiding behind a token it
    // does not need.
    if (section.service == AccountService.minecraft) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(section: section),
          const Expanded(child: McContentTab()),
        ],
      );
    }

    // YouTube carries its own OAuth credential and its own connect prompt,
    // so it bypasses the GitHub gate below exactly like Minecraft does.
    if (section.service == AccountService.youtube) {
      final youtube = YoutubeScope.of(context);
      if (!youtube.loaded) {
        return Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
          ),
        );
      }
      if (!youtube.connected) return const _YoutubeConnectPrompt();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(section: section),
          if (youtube.refreshing) const _YoutubeRefreshBar(),
          if (youtube.error case final message?)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AccountNotice(
                message: message,
                icon: Icons.error_outline_rounded,
                tone: luma.danger,
                onDismiss: youtube.clearError,
              ),
            ),
          if (youtube.warnings.isNotEmpty && !youtube.refreshing)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AccountNotice(message: youtube.warnings.join('\n')),
            ),
          Expanded(
            child: IndexedStack(
              index: _youtubeSections.indexOf(section).clamp(0, 2),
              children: [
                YoutubeOverviewTab(onOpenSection: onOpenSection),
                const YoutubeVideosTab(),
                const YoutubeAnalyticsTab(),
              ],
            ),
          ),
        ],
      );
    }

    if (!repository.loaded) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
        ),
      );
    }

    if (!repository.connected) return const _ConnectPrompt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(section: section),
        if (repository.refreshing) const _RefreshBar(),
        if (repository.error case final message?)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: AccountNotice(
              message: message,
              icon: Icons.error_outline_rounded,
              tone: luma.danger,
              onDismiss: repository.clearError,
            ),
          ),
        if (repository.warnings.isNotEmpty && !repository.refreshing)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: AccountNotice(
              message: repository.warnings.join('\n'),
            ),
          ),
        Expanded(
          // The sections are kept alive rather than rebuilt on every switch:
          // the repository list holds a scroll position, a search term and a
          // sort order, none of which should reset because the user glanced
          // at the usage meters.
          child: IndexedStack(
            // Indexed within GitHub's own sections rather than by the enum's
            // global index, so adding a section to another service cannot
            // silently shift these.
            index: _githubSections.indexOf(section).clamp(0, 4),
            children: [
              GithubOverviewTab(onOpenSection: onOpenSection),
              const GithubRepositoriesTab(),
              const GithubIssuesTab(),
              const GithubActionsTab(),
              const GithubUsageTab(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The section title strip, with the account chip and the refresh action —
/// GitHub keeps identity and page context on one line, and so does this.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.section});

  final AccountSection section;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final service = section.service;

    // Minecraft's refresh and settings live in its own toolbar, next to the
    // view switcher they belong with — repeating them here would give the
    // section two of each, so it gets neither a chip nor these actions.
    var chip = '';
    var refreshing = false;
    VoidCallback? onRefresh;
    VoidCallback? onSettings;
    if (service == AccountService.github) {
      final repository = AccountOverviewScope.of(context);
      chip = repository.credentials?.login ?? '';
      refreshing = repository.refreshing;
      onRefresh = refreshing ? null : repository.unawaitedRefresh;
      onSettings = () => showGithubConnectDialog(context);
    } else if (service == AccountService.youtube) {
      final youtube = YoutubeScope.of(context);
      chip = youtube.credentials?.channelTitle ?? '';
      refreshing = youtube.refreshing;
      onRefresh = refreshing ? null : youtube.unawaitedRefresh;
      onSettings = () => showYoutubeConnectDialog(context);
    }
    final hasActions = onSettings != null;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, hasActions ? 14 : 20, 14),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  section.label,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  section.blurb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (chip.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(service.icon, size: 13, color: luma.accent),
                  const SizedBox(width: 6),
                  Text(
                    chip,
                    style: TextStyle(
                      color: luma.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (hasActions) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: refreshing ? 'Refreshing…' : 'Refresh',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 19),
              color: luma.textSecondary,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
            IconButton(
              tooltip: 'Account settings',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              color: luma.textSecondary,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ],
        ],
      ),
    );
  }
}

/// A determinate-feeling progress strip that names the stage in flight,
/// because a refresh spans a dozen calls and "loading" says nothing about
/// which one is slow.
class _RefreshBar extends StatelessWidget {
  const _RefreshBar();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = AccountOverviewScope.of(context);
    final stage = repository.stage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      color: luma.accentSubtle,
      child: Row(
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stage == GithubLoadStage.idle ? 'Refreshing…' : '${stage.label}…',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            'Step ${stage.index} of ${GithubLoadStage.values.length - 1}',
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// [_RefreshBar]'s YouTube counterpart — same shape, keyed off
/// [YoutubeLoadStage] instead of [GithubLoadStage].
class _YoutubeRefreshBar extends StatelessWidget {
  const _YoutubeRefreshBar();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final youtube = YoutubeScope.of(context);
    final stage = youtube.stage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      color: luma.accentSubtle,
      child: Row(
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: luma.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              stage == YoutubeLoadStage.idle ? 'Refreshing…' : '${stage.label}…',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            'Step ${stage.index} of ${YoutubeLoadStage.values.length - 1}',
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the plugin shows before a token exists.
class _ConnectPrompt extends StatelessWidget {
  const _ConnectPrompt();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LumaEmptyState(
                icon: Icons.hub_rounded,
                title: 'Connect your GitHub account',
                subtitle: 'See your commits, stars, downloads, repositories, '
                    'issues and workflow runs in one place — plus your '
                    'Copilot, storage and compute allowances.',
                action: LumaPrimaryButton(
                  label: 'Connect GitHub',
                  icon: Icons.link_rounded,
                  onTap: () => showGithubConnectDialog(context),
                ),
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: luma.surface,
                  borderRadius: context.lumaDecor.cardBorderRadius,
                  border: Border.all(color: luma.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 17, color: luma.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'luma stores your personal access token encrypted on '
                        'this device and talks to api.github.com directly. '
                        'Nothing about your GitHub account is sent to a luma '
                        'server, and no account is needed to use this plugin.',
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [_ConnectPrompt]'s YouTube counterpart.
class _YoutubeConnectPrompt extends StatelessWidget {
  const _YoutubeConnectPrompt();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LumaEmptyState(
                icon: Icons.smart_display_rounded,
                title: 'Connect your YouTube channel',
                subtitle: 'See your subscribers, views, recent uploads and '
                    'deep analytics — watch time, traffic sources and '
                    'subscriber trends — in one place.',
                action: LumaPrimaryButton(
                  label: 'Connect YouTube',
                  icon: Icons.link_rounded,
                  onTap: () => showYoutubeConnectDialog(context),
                ),
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: luma.surface,
                  borderRadius: context.lumaDecor.cardBorderRadius,
                  border: Border.all(color: luma.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 17, color: luma.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "luma stores your Google OAuth credentials encrypted "
                        "on this device and talks to Google directly. "
                        "Nothing about your account is sent to a luma "
                        "server, and no luma account is needed to use this "
                        "plugin.",
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 12,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The collapsible rail. Expanded it shows an icon, a label and a blurb;
/// collapsed it is icons only, each with a tooltip so the destination is
/// still nameable — an icon with no accessible name is not a navigation
/// item.
class _SectionRail extends StatelessWidget {
  const _SectionRail({
    required this.selected,
    required this.collapsed,
    required this.showToggle,
    required this.connectedServices,
    required this.subtitles,
    required this.expandedService,
    required this.onSelect,
    required this.onToggleCollapsed,
    required this.onToggleServiceExpanded,
  });

  final AccountSection selected;
  final bool collapsed;

  /// False on narrow layouts, where the rail is collapsed by necessity and
  /// expanding it is not an option worth offering.
  final bool showToggle;

  /// Per-service readiness. Sections belonging to a service that is not set
  /// up read as unavailable rather than leading to an empty screen.
  final Map<AccountService, bool> connectedServices;

  /// Per-service line under the heading — an account name, or the platforms
  /// that are configured.
  final Map<AccountService, String?> subtitles;

  /// The one service whose section list is currently shown under its
  /// heading — null while every service is folded away.
  final AccountService? expandedService;

  final ValueChanged<AccountSection> onSelect;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<AccountService> onToggleServiceExpanded;

  static const double _expandedWidth = 210;
  static const double _collapsedWidth = 64;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final target = collapsed ? _collapsedWidth : _expandedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: target,
      decoration: BoxDecoration(color: luma.rail),
      clipBehavior: Clip.hardEdge,
      // The children swap to their new layout on the first frame, while the
      // rail is still animating to the width that fits them. Laying them out
      // at the target width and clipping the difference turns that frame
      // into a clean slide instead of an overflow.
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: target,
        maxWidth: target,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            // One heading per service, then that service's sections. The
            // rail is a list of accounts; this loop is the whole of what
            // adding another one costs.
            for (final service in AccountService.values) ...[
              _ServiceHeading(
                service: service,
                collapsed: collapsed,
                connected: connectedServices[service] ?? false,
                subtitle: subtitles[service],
                expanded: expandedService == service,
                // Collapsed or not, a service still has its own row of
                // icons to fold away — heading taps must keep working here
                // or a narrow rail can never reach any service but the one
                // it started on.
                onTap: () => onToggleServiceExpanded(service),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: expandedService != service
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 4),
                          for (final section in AccountSection.values)
                            if (section.service == service)
                              _RailItem(
                                section: section,
                                selected: section == selected,
                                collapsed: collapsed,
                                // A service that is not set up still needs a
                                // way in, or its setup screen is
                                // unreachable. Its first section stays live
                                // and carries the prompt; the rest read as
                                // unavailable until there is something
                                // behind them.
                                enabled: (connectedServices[service] ??
                                        false) ||
                                    section == _firstSectionOf(service),
                                onTap: () => onSelect(section),
                              ),
                        ],
                      ),
              ),
              const SizedBox(height: 10),
            ],
            const Spacer(),
            _MoreServicesHint(collapsed: collapsed),
            if (showToggle)
              _CollapseButton(collapsed: collapsed, onTap: onToggleCollapsed),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// The GitHub group header — the seam the next service is added along.
class _ServiceHeading extends StatelessWidget {
  const _ServiceHeading({
    required this.service,
    required this.collapsed,
    required this.connected,
    required this.subtitle,
    required this.expanded,
    required this.onTap,
  });

  final AccountService service;
  final bool collapsed;
  final bool connected;

  /// The account name, or the platforms configured for this service.
  final String? subtitle;

  /// Whether this service's sections are currently shown below it.
  final bool expanded;

  /// Null while the rail itself is icon-only — there is no list to fold.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final line =
        connected ? (subtitle ?? 'Connected') : 'Not set up';

    final content = Row(
      mainAxisAlignment:
          collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: luma.accentSubtle,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(service.icon, size: 17, color: luma.accent),
        ),
        if (!collapsed) ...[
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  service.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: connected ? luma.success : luma.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null)
            AnimatedRotation(
              duration: const Duration(milliseconds: 160),
              turns: expanded ? 0 : -0.25,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: luma.textMuted,
              ),
            ),
        ],
      ],
    );

    final padded = Padding(
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 12, vertical: 8),
      child: content,
    );

    return Tooltip(
      message: collapsed ? '${service.label} — $line' : '',
      child: onTap == null
          ? padded
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                hoverColor: luma.surfaceHover,
                child: Semantics(
                  label: '${service.label} section list',
                  button: true,
                  expanded: expanded,
                  child: padded,
                ),
              ),
            ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.section,
    required this.selected,
    required this.collapsed,
    required this.enabled,
    required this.onTap,
  });

  final AccountSection section;
  final bool selected;
  final bool collapsed;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final foreground = selected ? luma.textPrimary : luma.textSecondary;

    final row = Row(
      children: [
        // The selected marker is a bar, not just a tint: colour alone should
        // never be the only thing distinguishing the current destination.
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 3,
          height: 26,
          decoration: BoxDecoration(
            color: selected ? luma.accent : Colors.transparent,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(3),
            ),
          ),
        ),
        SizedBox(width: collapsed ? 17 : 13),
        Icon(section.icon, size: 20, color: selected ? luma.accent : foreground),
        if (!collapsed) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                Text(
                  section.blurb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
      ],
    );

    return Opacity(
      // Before a token exists there is nothing behind any of these, so they
      // read as unavailable instead of leading to five empty screens.
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Material(
          color: selected && enabled ? luma.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            hoverColor: luma.surfaceHover,
            child: Tooltip(
              message: collapsed ? '${section.label} — ${section.blurb}' : '',
              waitDuration: const Duration(milliseconds: 400),
              child: Semantics(
                label: section.label,
                selected: selected,
                enabled: enabled,
                button: true,
                child: SizedBox(height: 48, child: row),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Says out loud that the sidebar is a list of services and GitHub is the
/// first one — an empty area with no explanation reads as a bug.
class _MoreServicesHint extends StatelessWidget {
  const _MoreServicesHint({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Tooltip(
          message: 'More services coming',
          child: Icon(Icons.more_horiz_rounded, size: 18, color: luma.textMuted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Icon(Icons.more_horiz_rounded, size: 15, color: luma.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'More services coming',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapseButton extends StatelessWidget {
  const _CollapseButton({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final label = collapsed ? 'Expand sidebar' : 'Collapse sidebar';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: luma.surfaceHover,
          child: Tooltip(
            message: label,
            child: Semantics(
              label: label,
              button: true,
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    SizedBox(width: collapsed ? 20 : 16),
                    Icon(
                      collapsed
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                      size: 18,
                      color: luma.textMuted,
                    ),
                    if (!collapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Collapse',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: luma.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
