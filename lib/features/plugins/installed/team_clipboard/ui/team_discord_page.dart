import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/team_clipboard_api.dart';
import '../team_clipboard_controller.dart';
import '../team_clipboard_models.dart';
import '../team_discord_models.dart';
import 'team_clipboard_style.dart';

/// The Team Clipboard's Discord tab: link the team's bot, then manage its
/// automod, auto replies and tracked forums. The bot runs on the luma server; this page
/// only reads and saves its settings. Everyone on the team sees it, and only
/// leads get the controls.
class TeamDiscordPage extends StatefulWidget {
  const TeamDiscordPage({
    super.key,
    required this.controller,
    this.pollInterval = const Duration(seconds: 6),
  });

  final TeamClipboardController controller;

  /// How often the bot's status and activity are re-read while the tab is
  /// showing.
  final Duration pollInterval;

  @override
  State<TeamDiscordPage> createState() => _TeamDiscordPageState();
}

class _TeamDiscordPageState extends State<TeamDiscordPage> {
  TeamDiscordState? _state;
  String? _error;
  bool _busy = false;
  Timer? _poll;
  _Section _section = _Section.plugins;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_load);
    _poll = Timer.periodic(widget.pollInterval, (_) {
      if (!_busy) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final state = await widget.controller.discord((api) => api.discord());
      if (!mounted) return;
      setState(() {
        _state = state;
        _error = null;
      });
    } catch (e) {
      if (!mounted || quiet) return;
      setState(() => _error = '$e');
    }
  }

  /// Runs a change and shows the state it returns. Returns whether it
  /// went through; a refusal is shown in a snack bar.
  Future<bool> _apply(
    Future<TeamDiscordState> Function(TeamClipboardApi api) call,
  ) async {
    setState(() => _busy = true);
    try {
      final state = await widget.controller.discord(call);
      if (mounted) setState(() => _state = state);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveAutomod(List<TeamAutomodRule> rules) =>
      _apply((api) => api.saveDiscord(automod: rules));

  Future<void> _saveReplies(List<TeamReplyRule> rules) =>
      _apply((api) => api.saveDiscord(replies: rules));

  Future<void> _saveTrackers(List<TeamForumTracker> rules) =>
      _apply((api) => api.saveDiscord(trackers: rules));

  Future<void> _setPlugin(_Section plugin, bool on) => _apply(
    (api) => switch (plugin) {
      _Section.automod => api.saveDiscord(automodOn: on),
      _Section.forums => api.saveDiscord(forumsOn: on),
      _ => api.saveDiscord(repliesOn: on),
    },
  );

  void _go(_Section section) => setState(() => _section = section);

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final state = _state;
    if (state == null) {
      if (_error != null) {
        return LumaEmptyState(
          icon: Icons.cloud_off_rounded,
          title: t.teamClipboardErrorTitle,
          subtitle: _error,
          action: LumaPrimaryButton(
            label: t.commonRetry,
            icon: Icons.refresh_rounded,
            onTap: _load,
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 860;
        final content = SingleChildScrollView(
          key: ValueKey(_section),
          padding: EdgeInsets.fromLTRB(
            wide ? 40 : 14,
            wide ? 32 : 16,
            wide ? 40 : 14,
            32,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: _page(context, state),
            ),
          ),
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(state: state, section: _section, onSection: _go),
              Expanded(child: content),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: luma.surface,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BotIdentity(state: state, onTap: () => _go(_Section.bot)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final s in _Section.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(_sectionLabel(t, s)),
                              avatar: Icon(_sectionIcon(s), size: 16),
                              showCheckmark: false,
                              selected: _section == s,
                              onSelected: (_) => _go(s),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: luma.border),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  Widget _page(BuildContext context, TeamDiscordState state) {
    final t = L.of(context);
    final lead = state.canManage;
    switch (_section) {
      case _Section.plugins:
        return _PluginsOverview(
          state: state,
          busy: _busy,
          onOpen: _go,
          onEnable: (plugin) async {
            await _setPlugin(plugin, true);
            if (mounted) _go(plugin);
          },
          onBotSettings: () => _go(_Section.bot),
        );
      case _Section.automod:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PluginHeader(
              section: _Section.automod,
              hint: t.teamDiscordAutomodHint,
              on: state.automodOn,
              lead: lead,
              busy: _busy,
              onBack: () => _go(_Section.plugins),
              onToggle: (on) => _setPlugin(_Section.automod, on),
            ),
            const SizedBox(height: 20),
            _RulesCard(
              key: const ValueKey('team-discord-automod'),
              icon: Icons.rule_rounded,
              title: t.teamDiscordRules,
              empty: t.teamDiscordNoAutomod,
              lead: lead,
              busy: _busy,
              onAdd: () async {
                final rule = await _editAutomod(context, null);
                if (rule != null) {
                  await _saveAutomod([...state.automod, rule]);
                }
              },
              tiles: [
                for (final (i, rule) in state.automod.indexed)
                  _RuleTile(
                    words: rule.words,
                    summary: _automodSummary(t, rule),
                    enabled: rule.enabled,
                    lead: lead,
                    busy: _busy,
                    onEnabled: (on) => _saveAutomod([
                      for (final r in state.automod)
                        r == rule ? r.copyWith(enabled: on) : r,
                    ]),
                    onEdit: () async {
                      final edited = await _editAutomod(context, rule);
                      if (edited != null) {
                        await _saveAutomod([...state.automod]..[i] = edited);
                      }
                    },
                    onDelete: () =>
                        _saveAutomod([...state.automod]..removeAt(i)),
                  ),
              ],
            ),
          ],
        );
      case _Section.replies:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PluginHeader(
              section: _Section.replies,
              hint: t.teamDiscordRepliesHint,
              on: state.repliesOn,
              lead: lead,
              busy: _busy,
              onBack: () => _go(_Section.plugins),
              onToggle: (on) => _setPlugin(_Section.replies, on),
            ),
            const SizedBox(height: 20),
            _RulesCard(
              key: const ValueKey('team-discord-replies'),
              icon: Icons.rule_rounded,
              title: t.teamDiscordRules,
              empty: t.teamDiscordNoReplies,
              lead: lead,
              busy: _busy,
              onAdd: () async {
                final rule = await _editReply(context, null);
                if (rule != null) {
                  await _saveReplies([...state.replies, rule]);
                }
              },
              tiles: [
                for (final (i, rule) in state.replies.indexed)
                  _RuleTile(
                    words: rule.triggers,
                    summary: '${_matchLabel(t, rule.match)} · ${rule.reply}',
                    enabled: rule.enabled,
                    lead: lead,
                    busy: _busy,
                    onEnabled: (on) => _saveReplies([
                      for (final r in state.replies)
                        r == rule ? r.copyWith(enabled: on) : r,
                    ]),
                    onEdit: () async {
                      final edited = await _editReply(context, rule);
                      if (edited != null) {
                        await _saveReplies([...state.replies]..[i] = edited);
                      }
                    },
                    onDelete: () =>
                        _saveReplies([...state.replies]..removeAt(i)),
                  ),
              ],
            ),
          ],
        );
      case _Section.forums:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PluginHeader(
              section: _Section.forums,
              hint: t.teamDiscordForumsHint,
              on: state.forumsOn,
              lead: lead,
              busy: _busy,
              onBack: () => _go(_Section.plugins),
              onToggle: (on) => _setPlugin(_Section.forums, on),
            ),
            const SizedBox(height: 20),
            _RulesCard(
              key: const ValueKey('team-discord-forums'),
              icon: Icons.rule_rounded,
              title: t.teamDiscordRules,
              empty: t.teamDiscordNoForumRules,
              lead: lead,
              busy: _busy,
              onAdd: () async {
                final rule = await _editForum(context, state, null);
                if (rule != null) {
                  await _saveTrackers([...state.trackers, rule]);
                }
              },
              tiles: [
                for (final (i, rule) in state.trackers.indexed)
                  _RuleTile(
                    words: [
                      '#${_forumName(state, rule)}',
                      if (rule.tags.isEmpty)
                        t.teamDiscordAllPosts
                      else
                        for (final tag in rule.tags) tag.name,
                    ],
                    summary: [
                      teamKindLabel(t, rule.kind),
                      if (rule.require != TeamForumRequire.none)
                        _requireLabel(t, rule.require),
                    ].join(' · '),
                    enabled: rule.enabled,
                    lead: lead,
                    busy: _busy,
                    onEnabled: (on) => _saveTrackers([
                      for (final r in state.trackers)
                        r == rule ? r.copyWith(enabled: on) : r,
                    ]),
                    onEdit: () async {
                      final edited = await _editForum(context, state, rule);
                      if (edited != null) {
                        await _saveTrackers([...state.trackers]..[i] = edited);
                      }
                    },
                    onDelete: () =>
                        _saveTrackers([...state.trackers]..removeAt(i)),
                  ),
              ],
            ),
          ],
        );
      case _Section.bot:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageTitle(t.teamDiscordBotSettings),
            const SizedBox(height: 20),
            _ConnectionCard(
              state: state,
              busy: _busy,
              onLink: (token) => _apply((api) => api.linkDiscord(token)),
              onUnlink: () => _apply((api) => api.unlinkDiscord()),
              onEnabled: (on) => _apply((api) => api.saveDiscord(enabled: on)),
            ),
          ],
        );
      case _Section.activity:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_ActivityCard(log: state.log)],
        );
    }
  }
}

/// Where the Discord tab is: the plugin grid, one plugin, the bot's own
/// settings or its activity.
enum _Section { plugins, automod, replies, forums, bot, activity }

bool _isPlugin(_Section s) =>
    s == _Section.automod || s == _Section.replies || s == _Section.forums;

String _sectionLabel(L t, _Section s) => switch (s) {
  _Section.plugins => t.teamDiscordPlugins,
  _Section.automod => t.teamDiscordAutomodTitle,
  _Section.replies => t.teamDiscordRepliesTitle,
  _Section.forums => t.teamDiscordForumsTitle,
  _Section.bot => t.teamDiscordBotSettings,
  _Section.activity => t.teamDiscordActivity,
};

IconData _sectionIcon(_Section s) => switch (s) {
  _Section.plugins => Icons.grid_view_rounded,
  _Section.automod => Icons.shield_rounded,
  _Section.replies => Icons.quickreply_rounded,
  _Section.forums => Icons.forum_rounded,
  _Section.bot => Icons.settings_rounded,
  _Section.activity => Icons.history_rounded,
};

bool _pluginOn(TeamDiscordState state, _Section s) => switch (s) {
  _Section.automod => state.automodOn,
  _Section.forums => state.forumsOn,
  _ => state.repliesOn,
};

/// A tracked forum's name as the bot sees it now, or as it was saved.
String _forumName(TeamDiscordState state, TeamForumTracker rule) =>
    state.forums.where((f) => f.id == rule.forumId).firstOrNull?.name ??
    rule.forumName;

String _requireLabel(L t, TeamForumRequire require) => switch (require) {
  TeamForumRequire.none => t.teamDiscordRequireNone,
  TeamForumRequire.image => t.teamDiscordRequireImage,
  TeamForumRequire.log => t.teamDiscordRequireLog,
  TeamForumRequire.either => t.teamDiscordRequireEither,
  TeamForumRequire.both => t.teamDiscordRequireBoth,
};

class _PageTitle extends StatelessWidget {
  const _PageTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: context.luma.textPrimary,
      fontSize: 24,
      fontWeight: FontWeight.w800,
    ),
  );
}

/// A plugin's icon on its tile: a rounded square in the accent colour, the
/// way bot dashboards badge their plugins.
class _PluginIcon extends StatelessWidget {
  const _PluginIcon(this.icon, {this.size = 56});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(luma.accent, Colors.white, 0.12)!,
            Color.lerp(luma.accent, Colors.black, 0.28)!,
          ],
        ),
      ),
      child: Icon(icon, color: luma.onAccent, size: size * 0.5),
    );
  }
}

/// The bot as the sidebar's top card: its avatar, name, the server it
/// sits in and whether it is online.
class _BotIdentity extends StatelessWidget {
  const _BotIdentity({required this.state, required this.onTap});

  final TeamDiscordState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final name = state.linked
        ? state.botName ?? t.teamClipboardDiscordBot
        : t.teamDiscordNoBot;
    final dot = switch (state.status) {
      TeamDiscordStatus.online => luma.success,
      TeamDiscordStatus.connecting => luma.warning,
      TeamDiscordStatus.error => luma.danger,
      TeamDiscordStatus.off => luma.textMuted,
    };
    return Material(
      color: luma.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('team-discord-identity'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: luma.accent.withValues(alpha: 0.18),
                    child: Text(
                      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: luma.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                        border: Border.all(color: luma.background, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (state.guilds.isNotEmpty)
                      Text(
                        state.guilds.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: luma.textMuted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: luma.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.state,
    required this.section,
    required this.onSection,
  });

  final TeamDiscordState state;
  final _Section section;
  final ValueChanged<_Section> onSection;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    Widget item(_Section s, {bool nested = false}) {
      final selected = s == section;
      final on = _isPlugin(s) ? _pluginOn(state, s) : null;
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected
              ? luma.accent.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: ValueKey('team-discord-nav-${s.name}'),
            onTap: () => onSection(s),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.fromLTRB(nested ? 10 : 12, 9, 10, 9),
              child: Row(
                children: [
                  if (nested) ...[
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: luma.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    _sectionIcon(s),
                    size: 18,
                    color: selected ? luma.accent : luma.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _sectionLabel(t, s),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? luma.textPrimary : luma.textSecondary,
                        fontSize: 13.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (on != null)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: on ? luma.success : luma.border,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 264,
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(right: BorderSide(color: luma.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
        children: [
          _BotIdentity(state: state, onTap: () => onSection(_Section.bot)),
          const SizedBox(height: 18),
          item(_Section.plugins),
          item(_Section.bot),
          item(_Section.activity),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
            child: Text(
              t.teamDiscordEssentials.toUpperCase(),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
          ),
          item(_Section.automod, nested: true),
          item(_Section.replies, nested: true),
          item(_Section.forums, nested: true),
        ],
      ),
    );
  }
}

/// The plugin grid: one card per plugin, each with its icon, what it does
/// and an Enable button.
class _PluginsOverview extends StatelessWidget {
  const _PluginsOverview({
    required this.state,
    required this.busy,
    required this.onOpen,
    required this.onEnable,
    required this.onBotSettings,
  });

  final TeamDiscordState state;
  final bool busy;
  final ValueChanged<_Section> onOpen;
  final ValueChanged<_Section> onEnable;
  final VoidCallback onBotSettings;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final plugins = [
      (_Section.automod, t.teamDiscordAutomodHint, state.automod.length),
      (_Section.replies, t.teamDiscordRepliesHint, state.replies.length),
      (_Section.forums, t.teamDiscordForumsHint, state.trackers.length),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PageTitle(t.teamDiscordPlugins),
        const SizedBox(height: 6),
        Text(
          t.teamDiscordPluginsHint,
          style: TextStyle(color: luma.textMuted, fontSize: 13.5),
        ),
        if (!state.linked) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: luma.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: luma.warning.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.link_off_rounded, color: luma.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.teamDiscordNotLinkedBanner,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13.5),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onBotSettings,
                  child: Text(t.teamDiscordBotSettings),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: luma.textSecondary, width: 1.5),
              ),
            ),
            child: Text(
              t.teamDiscordEssentials,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, box) {
            const gap = 20.0;
            final columns = ((box.maxWidth + gap) / (300 + gap)).floor().clamp(
              1,
              4,
            );
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (section, hint, count) in plugins)
                  SizedBox(
                    width: width,
                    child: _PluginCard(
                      section: section,
                      hint: hint,
                      ruleCount: count,
                      on: _pluginOn(state, section),
                      lead: state.canManage,
                      busy: busy,
                      onOpen: () => onOpen(section),
                      onEnable: () => onEnable(section),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PluginCard extends StatelessWidget {
  const _PluginCard({
    required this.section,
    required this.hint,
    required this.ruleCount,
    required this.on,
    required this.lead,
    required this.busy,
    required this.onOpen,
    required this.onEnable,
  });

  final _Section section;
  final String hint;
  final int ruleCount;
  final bool on;
  final bool lead;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final enable = lead && !on;
    final button = TextButton.icon(
      key: ValueKey('team-discord-card-${section.name}'),
      onPressed: busy ? null : (enable ? onEnable : onOpen),
      style: TextButton.styleFrom(
        backgroundColor: luma.surfaceHover,
        foregroundColor: luma.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      icon: Icon(
        enable
            ? Icons.add_rounded
            : lead
            ? Icons.tune_rounded
            : Icons.visibility_outlined,
        size: 18,
      ),
      label: Text(
        enable
            ? t.teamDiscordEnable
            : lead
            ? t.teamDiscordManage
            : t.teamDiscordView,
      ),
    );
    return Material(
      color: luma.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          constraints: const BoxConstraints(minHeight: 252),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: luma.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PluginIcon(_sectionIcon(section)),
                  const Spacer(),
                  TeamPill(
                    label: on ? t.teamDiscordEnabled : t.teamDiscordPluginOff,
                    color: on ? luma.success : luma.textMuted,
                    icon: on ? Icons.check_rounded : null,
                    filled: on,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _sectionLabel(t, section),
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hint,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t.teamDiscordRuleCount(ruleCount),
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 20),
              button,
            ],
          ),
        ),
      ),
    );
  }
}

/// The top of a plugin's own page: its badge, name, what it does, and the
/// switch that turns the whole plugin on or off.
class _PluginHeader extends StatelessWidget {
  const _PluginHeader({
    required this.section,
    required this.hint,
    required this.on,
    required this.lead,
    required this.busy,
    required this.onBack,
    required this.onToggle,
  });

  final _Section section;
  final String hint;
  final bool on;
  final bool lead;
  final bool busy;
  final VoidCallback onBack;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBack,
          style: TextButton.styleFrom(
            foregroundColor: luma.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(t.teamDiscordPlugins),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PluginIcon(_sectionIcon(section), size: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PageTitle(_sectionLabel(t, section)),
                  const SizedBox(height: 4),
                  Text(
                    hint,
                    style: TextStyle(color: luma.textMuted, fontSize: 13.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (lead)
              Switch(
                key: ValueKey('team-discord-plugin-${section.name}'),
                value: on,
                onChanged: busy ? null : onToggle,
              )
            else
              TeamPill(
                label: on ? t.teamDiscordEnabled : t.teamDiscordPluginOff,
                color: on ? luma.success : luma.textMuted,
              ),
          ],
        ),
      ],
    );
  }
}

String _durationLabel(L t, int minutes) {
  if (minutes < 60) return t.teamDiscordMinutes(minutes);
  if (minutes < 1440) return t.teamDiscordHours(minutes ~/ 60);
  return t.teamDiscordDays(minutes ~/ 1440);
}

String _automodSummary(L t, TeamAutomodRule rule) => [
  rule.wholeWord ? t.teamDiscordWholeWord : t.teamDiscordMatchContains,
  if (rule.warn.isNotEmpty) t.teamDiscordWarns,
  if (rule.timeoutMinutes > 0)
    t.teamDiscordTimeoutShort(_durationLabel(t, rule.timeoutMinutes)),
].join(' · ');

String _matchLabel(L t, TeamReplyMatch match) => switch (match) {
  TeamReplyMatch.word => t.teamDiscordMatchWord,
  TeamReplyMatch.contains => t.teamDiscordMatchContains,
  TeamReplyMatch.exact => t.teamDiscordMatchExact,
};

Future<void> _open(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.hint});

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: luma.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  hint!,
                  style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Whether the bot is linked and online, where it is, and (for a lead) the
/// token, the on switch and the invite link.
class _ConnectionCard extends StatefulWidget {
  const _ConnectionCard({
    required this.state,
    required this.busy,
    required this.onLink,
    required this.onUnlink,
    required this.onEnabled,
  });

  final TeamDiscordState state;
  final bool busy;
  final Future<bool> Function(String token) onLink;
  final Future<bool> Function() onUnlink;
  final Future<bool> Function(bool on) onEnabled;

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  final _token = TextEditingController();
  bool _replacing = false;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final token = _token.text.trim();
    if (token.isEmpty) return;
    if (await widget.onLink(token) && mounted) {
      _token.clear();
      setState(() => _replacing = false);
    }
  }

  Future<void> _confirmUnlink() async {
    final t = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.teamDiscordUnlink),
        content: Text(
          t.teamDiscordUnlinkConfirm(widget.state.botName ?? 'bot'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              t.teamDiscordUnlink,
              style: TextStyle(color: context.luma.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await widget.onUnlink();
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final state = widget.state;
    final lead = state.canManage;

    if (!state.linked) {
      return LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(
              icon: Icons.smart_toy_outlined,
              title: t.teamDiscordSetupTitle,
              hint: t.teamDiscordSetupBody,
            ),
            const SizedBox(height: 16),
            if (!lead)
              Text(
                t.teamDiscordNotLinkedMember,
                style: TextStyle(color: luma.textSecondary, fontSize: 13.5),
              )
            else ...[
              for (final (i, step) in [
                t.teamDiscordStep1,
                t.teamDiscordStep2,
                t.teamDiscordStep3,
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: luma.accent.withValues(alpha: 0.15),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: luma.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(
                            color: luma.textSecondary,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      _open('https://discord.com/developers/applications'),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(t.teamDiscordOpenPortal),
                ),
              ),
              const SizedBox(height: 8),
              _tokenRow(t),
            ],
          ],
        ),
      );
    }

    final (statusLabel, statusColor, statusIcon) = switch (state.status) {
      TeamDiscordStatus.online => (
        t.teamDiscordStatusOnline,
        luma.success,
        Icons.circle,
      ),
      TeamDiscordStatus.connecting => (
        t.teamDiscordStatusConnecting,
        luma.warning,
        Icons.sync_rounded,
      ),
      TeamDiscordStatus.error => (
        t.teamDiscordStatusError,
        luma.danger,
        Icons.error_outline_rounded,
      ),
      TeamDiscordStatus.off => (
        t.teamDiscordStatusOff,
        luma.textSecondary,
        Icons.circle_outlined,
      ),
    };
    final problem = state.status == TeamDiscordStatus.error
        ? switch (state.statusReason) {
            'bad_token' => t.teamDiscordErrorBadToken,
            'intents' => t.teamDiscordErrorIntents,
            'network' => t.teamDiscordErrorNetwork,
            _ => t.teamDiscordErrorOther,
          }
        : null;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: luma.accent.withValues(alpha: 0.14),
                child: Icon(Icons.smart_toy_outlined, color: luma.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.botName ?? t.teamClipboardDiscordBot,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.guilds.isEmpty
                          ? t.teamDiscordNoServers
                          : t.teamDiscordInServers(state.guilds.join(', ')),
                      style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TeamPill(
                label: statusLabel,
                color: statusColor,
                icon: statusIcon,
              ),
              if (lead) ...[
                const SizedBox(width: 8),
                Switch(
                  key: const ValueKey('team-discord-enabled'),
                  value: state.enabled,
                  onChanged: widget.busy ? null : widget.onEnabled,
                ),
              ],
            ],
          ),
          if (problem != null) ...[
            const SizedBox(height: 12),
            Text(problem, style: TextStyle(color: luma.danger, fontSize: 13)),
          ],
          if (lead) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (state.inviteUrl != null)
                  IntrinsicWidth(
                    child: LumaPrimaryButton(
                      label: t.teamDiscordAddToServer,
                      icon: Icons.add_link_rounded,
                      onTap: () => _open(state.inviteUrl!),
                    ),
                  ),
                IntrinsicWidth(
                  child: LumaGhostButton(
                    label: t.teamDiscordReplaceToken,
                    icon: Icons.key_rounded,
                    onTap: widget.busy
                        ? null
                        : () => setState(() => _replacing = !_replacing),
                  ),
                ),
                IntrinsicWidth(
                  child: LumaGhostButton(
                    label: t.teamDiscordUnlink,
                    icon: Icons.link_off_rounded,
                    onTap: widget.busy ? null : _confirmUnlink,
                  ),
                ),
              ],
            ),
            if (_replacing) ...[const SizedBox(height: 12), _tokenRow(t)],
          ] else ...[
            const SizedBox(height: 10),
            Text(
              t.teamDiscordLeadOnly,
              style: TextStyle(color: luma.textMuted, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tokenRow(L t) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextField(
          key: const ValueKey('team-discord-token'),
          controller: _token,
          enabled: !widget.busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _link(),
          decoration: InputDecoration(
            isDense: true,
            labelText: t.teamDiscordTokenLabel,
          ),
        ),
      ),
      const SizedBox(width: 10),
      LumaPrimaryButton(
        label: t.teamDiscordLink,
        icon: Icons.link_rounded,
        loading: widget.busy,
        onTap: widget.busy ? null : _link,
      ),
    ],
  );
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({
    super.key,
    required this.icon,
    required this.title,
    required this.empty,
    required this.lead,
    required this.busy,
    required this.onAdd,
    required this.tiles,
  });

  final IconData icon;
  final String title;
  final String empty;
  final bool lead;
  final bool busy;
  final VoidCallback onAdd;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _SectionTitle(icon: icon, title: title),
              ),
              if (lead)
                TextButton.icon(
                  onPressed: busy ? null : onAdd,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(t.teamDiscordAddRule),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (tiles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                empty,
                style: TextStyle(color: luma.textMuted, fontSize: 13),
              ),
            )
          else
            for (final (i, tile) in tiles.indexed) ...[
              if (i > 0) Divider(height: 1, color: luma.border),
              tile,
            ],
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.words,
    required this.summary,
    required this.enabled,
    required this.lead,
    required this.busy,
    required this.onEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  final List<String> words;
  final String summary;
  final bool enabled;
  final bool lead;
  final bool busy;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _shownWords = 8;

  Future<void> _confirmDelete(BuildContext context) async {
    final t = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.teamDiscordDeleteRule),
        content: Text(words.join(', ')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              t.commonDelete,
              style: TextStyle(color: context.luma.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final content = Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in words.take(_shownWords))
                TeamPill(label: w, color: luma.textSecondary),
              if (words.length > _shownWords)
                TeamPill(
                  label: '+${words.length - _shownWords}',
                  color: luma.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: luma.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
    return InkWell(
      onTap: lead && !busy ? onEdit : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(child: content),
            if (lead) ...[
              Switch(value: enabled, onChanged: busy ? null : onEnabled),
              IconButton(
                tooltip: t.teamDiscordDeleteRule,
                onPressed: busy ? null : () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: luma.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.log});

  final List<TeamDiscordLogEntry> log;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.history_rounded,
            title: t.teamDiscordActivity,
          ),
          const SizedBox(height: 12),
          if (log.isEmpty)
            Text(
              t.teamDiscordNoActivity,
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            )
          else
            for (final e in log.take(30))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      switch (e.kind) {
                        'automod' => Icons.shield_outlined,
                        'reply' => Icons.quickreply_outlined,
                        'forum' => Icons.forum_outlined,
                        'forum_done' => Icons.task_alt_rounded,
                        'error' => Icons.error_outline_rounded,
                        _ => Icons.info_outline_rounded,
                      },
                      size: 16,
                      color: switch (e.kind) {
                        'automod' => luma.warning,
                        'reply' || 'forum' => luma.accent,
                        'forum_done' => luma.success,
                        'error' => luma.danger,
                        _ => luma.textMuted,
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        [
                          switch (e.kind) {
                            'automod' => t.teamDiscordLogAutomod(
                              e.user,
                              e.detail,
                            ),
                            'reply' => t.teamDiscordLogReply(e.user, e.detail),
                            'forum' => t.teamDiscordLogForum(e.user, e.detail),
                            'forum_done' => t.teamDiscordLogForumDone(e.detail),
                            _ => e.detail,
                          },
                          if (e.channel.isNotEmpty) '#${e.channel}',
                        ].join(' · '),
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      teamRelativeTime(
                        context,
                        DateTime.fromMillisecondsSinceEpoch(e.atMs),
                      ),
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ---- Rule editors -----------------------------------------------------------

const _timeoutChoices = [0, 1, 5, 10, 60, 1440, 10080];

Future<TeamAutomodRule?> _editAutomod(
  BuildContext context,
  TeamAutomodRule? existing,
) => showDialog<TeamAutomodRule>(
  context: context,
  builder: (context) => _AutomodEditor(existing: existing),
);

Future<TeamReplyRule?> _editReply(
  BuildContext context,
  TeamReplyRule? existing,
) => showDialog<TeamReplyRule>(
  context: context,
  builder: (context) => _ReplyEditor(existing: existing),
);

Future<TeamForumTracker?> _editForum(
  BuildContext context,
  TeamDiscordState state,
  TeamForumTracker? existing,
) => showDialog<TeamForumTracker>(
  context: context,
  builder: (context) => _ForumEditor(state: state, existing: existing),
);

class _EditorShell extends StatelessWidget {
  const _EditorShell({
    required this.title,
    required this.onSave,
    required this.children,
    this.spacious = false,
  });

  final String title;
  final VoidCallback onSave;
  final List<Widget> children;
  final bool spacious;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    if (!spacious) {
      return Dialog(
        backgroundColor: luma.surface,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                ...children,
                const SizedBox(height: 20),
                _actions(context, t),
              ],
            ),
          ),
        ),
      );
    }
    return Dialog(
      backgroundColor: luma.surface,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _actions(context, t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, L t) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      LumaGhostButton(
        label: t.commonCancel,
        onTap: () => Navigator.of(context).pop(),
      ),
      const SizedBox(width: 10),
      LumaPrimaryButton(
        label: t.commonSave,
        icon: Icons.check_rounded,
        onTap: onSave,
      ),
    ],
  );
}

class _AutomodEditor extends StatefulWidget {
  const _AutomodEditor({this.existing});

  final TeamAutomodRule? existing;

  @override
  State<_AutomodEditor> createState() => _AutomodEditorState();
}

class _AutomodEditorState extends State<_AutomodEditor> {
  late final _words = TextEditingController(
    text: widget.existing?.words.join('\n'),
  );
  late final _warn = TextEditingController(text: widget.existing?.warn);
  late bool _whole = widget.existing?.wholeWord ?? true;
  late int _timeout = widget.existing?.timeoutMinutes ?? 0;
  bool _wordsMissing = false;

  @override
  void dispose() {
    _words.dispose();
    _warn.dispose();
    super.dispose();
  }

  void _save() {
    final words = splitTeamDiscordWords(_words.text);
    if (words.isEmpty) {
      setState(() => _wordsMissing = true);
      return;
    }
    Navigator.of(context).pop(
      TeamAutomodRule(
        id: widget.existing?.id,
        words: words.take(50).toList(),
        wholeWord: _whole,
        warn: _warn.text.trim(),
        timeoutMinutes: _timeout,
        enabled: widget.existing?.enabled ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final choices = {..._timeoutChoices, _timeout}.toList()..sort();
    return _EditorShell(
      title: widget.existing == null
          ? t.teamDiscordNewAutomod
          : t.teamDiscordEditAutomod,
      onSave: _save,
      children: [
        TextField(
          key: const ValueKey('team-discord-words'),
          controller: _words,
          autofocus: widget.existing == null,
          minLines: 3,
          maxLines: 8,
          onChanged: (_) {
            if (_wordsMissing) setState(() => _wordsMissing = false);
          },
          decoration: InputDecoration(
            labelText: t.teamDiscordWordsLabel,
            hintText: t.teamDiscordWordsHint,
            errorText: _wordsMissing ? t.teamDiscordWordsRequired : null,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _whole,
          onChanged: (v) => setState(() => _whole = v),
          title: Text(t.teamDiscordWholeWord),
          subtitle: Text(t.teamDiscordWholeWordHint),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _warn,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: t.teamDiscordWarnLabel,
            hintText: t.teamDiscordWarnHint,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _timeout,
          decoration: InputDecoration(
            isDense: true,
            labelText: t.teamDiscordTimeoutLabel,
          ),
          items: [
            for (final m in choices)
              DropdownMenuItem(
                value: m,
                child: Text(
                  m == 0 ? t.teamDiscordTimeoutNone : _durationLabel(t, m),
                ),
              ),
          ],
          onChanged: (m) => setState(() => _timeout = m ?? 0),
        ),
      ],
    );
  }
}

class _ReplyEditor extends StatefulWidget {
  const _ReplyEditor({this.existing});

  final TeamReplyRule? existing;

  @override
  State<_ReplyEditor> createState() => _ReplyEditorState();
}

class _ReplyEditorState extends State<_ReplyEditor> {
  late final _triggers = TextEditingController(
    text: widget.existing?.triggers.join('\n'),
  );
  late final _reply = TextEditingController(text: widget.existing?.reply);
  late TeamReplyMatch _match = widget.existing?.match ?? TeamReplyMatch.word;
  bool _triggersMissing = false;
  bool _replyMissing = false;

  @override
  void dispose() {
    _triggers.dispose();
    _reply.dispose();
    super.dispose();
  }

  void _save() {
    final triggers = splitTeamDiscordWords(_triggers.text);
    final reply = _reply.text.trim();
    if (triggers.isEmpty || reply.isEmpty) {
      setState(() {
        _triggersMissing = triggers.isEmpty;
        _replyMissing = reply.isEmpty;
      });
      return;
    }
    Navigator.of(context).pop(
      TeamReplyRule(
        id: widget.existing?.id,
        triggers: triggers.take(50).toList(),
        reply: reply,
        match: _match,
        enabled: widget.existing?.enabled ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return _EditorShell(
      title: widget.existing == null
          ? t.teamDiscordNewReply
          : t.teamDiscordEditReply,
      onSave: _save,
      children: [
        TextField(
          key: const ValueKey('team-discord-triggers'),
          controller: _triggers,
          autofocus: widget.existing == null,
          minLines: 2,
          maxLines: 6,
          onChanged: (_) {
            if (_triggersMissing) setState(() => _triggersMissing = false);
          },
          decoration: InputDecoration(
            labelText: t.teamDiscordTriggersLabel,
            hintText: t.teamDiscordWordsHint,
            errorText: _triggersMissing ? t.teamDiscordWordsRequired : null,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TeamReplyMatch>(
          initialValue: _match,
          decoration: InputDecoration(
            isDense: true,
            labelText: t.teamDiscordMatchLabel,
          ),
          items: [
            for (final m in TeamReplyMatch.values)
              DropdownMenuItem(value: m, child: Text(_matchLabel(t, m))),
          ],
          onChanged: (m) => setState(() => _match = m ?? _match),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('team-discord-reply'),
          controller: _reply,
          minLines: 3,
          maxLines: 8,
          maxLength: 2000,
          onChanged: (_) {
            if (_replyMissing) setState(() => _replyMissing = false);
          },
          decoration: InputDecoration(
            labelText: t.teamDiscordReplyLabel,
            errorText: _replyMissing ? t.teamDiscordReplyRequired : null,
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

/// Picks a forum (and maybe some of its tags), what its posts become on
/// the board, what they must include, and what the bot says.
class _ForumEditor extends StatefulWidget {
  const _ForumEditor({required this.state, this.existing});

  final TeamDiscordState state;
  final TeamForumTracker? existing;

  @override
  State<_ForumEditor> createState() => _ForumEditorState();
}

class _ForumEditorState extends State<_ForumEditor> {
  late String? _forumId = widget.existing?.forumId;
  late final Set<TeamDiscordTag> _tags = {...?widget.existing?.tags};
  late TeamEntryKind _kind = widget.existing?.kind ?? TeamEntryKind.bug;
  late TeamForumRequire _require =
      widget.existing?.require ?? TeamForumRequire.both;
  TextEditingController? _missing;
  TextEditingController? _done;
  bool _forumMissing = false;

  /// The forums the bot sees, plus the saved one while the bot can't see
  /// it (offline, say), so editing never loses it.
  late final List<TeamDiscordForum> _forums = [
    ...widget.state.forums,
    if (widget.existing case final e?
        when !widget.state.forums.any((f) => f.id == e.forumId))
      TeamDiscordForum(id: e.forumId, name: e.forumName, tags: e.tags),
  ];

  TeamDiscordForum? get _forum =>
      _forums.where((f) => f.id == _forumId).firstOrNull;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final t = L.of(context);
    _missing ??= TextEditingController(
      text: widget.existing?.missingMessage ?? t.teamDiscordMissingDefault,
    );
    _done ??= TextEditingController(
      text:
          widget.existing?.doneMessage ?? t.teamDiscordDoneDefault('{status}'),
    );
  }

  @override
  void dispose() {
    _missing?.dispose();
    _done?.dispose();
    super.dispose();
  }

  void _save() {
    final forum = _forum;
    if (forum == null) {
      setState(() => _forumMissing = true);
      return;
    }
    Navigator.of(context).pop(
      TeamForumTracker(
        id: widget.existing?.id,
        forumId: forum.id,
        forumName: forum.name,
        tags: _tags.toList(),
        kind: _kind,
        require: _require,
        missingMessage: _require == TeamForumRequire.none
            ? ''
            : _missing!.text.trim(),
        doneMessage: _done!.text.trim(),
        enabled: widget.existing?.enabled ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final forum = _forum;
    final tags = [
      ...?forum?.tags,
      for (final tag in _tags)
        if (!(forum?.tags.contains(tag) ?? false)) tag,
    ];
    return _EditorShell(
      title: widget.existing == null
          ? t.teamDiscordNewForum
          : t.teamDiscordEditForum,
      spacious: true,
      onSave: _save,
      children: [
        if (_forums.isEmpty)
          Text(
            t.teamDiscordNoForumsSeen,
            style: TextStyle(color: luma.warning, fontSize: 13),
          )
        else
          DropdownButtonFormField<String>(
            key: const ValueKey('team-discord-forum'),
            isExpanded: true,
            initialValue: _forumId,
            decoration: _fieldDecoration(t.teamDiscordForumLabel).copyWith(
              errorText: _forumMissing ? t.teamDiscordForumRequired : null,
            ),
            items: [
              for (final f in _forums)
                DropdownMenuItem(
                  value: f.id,
                  child: Text(
                    f.guild.isEmpty ? '#${f.name}' : '#${f.name} · ${f.guild}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) => setState(() {
              if (id != _forumId) _tags.clear();
              _forumId = id;
              _forumMissing = false;
            }),
          ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            t.teamDiscordTagsLabel,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            t.teamDiscordTagsHint,
            style: TextStyle(color: luma.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                FilterChip(
                  label: Text(tag.name),
                  selected: _tags.contains(tag),
                  onSelected: (on) =>
                      setState(() => on ? _tags.add(tag) : _tags.remove(tag)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        DropdownButtonFormField<TeamEntryKind>(
          isExpanded: true,
          initialValue: _kind,
          decoration: _fieldDecoration(t.teamDiscordKindLabel),
          items: [
            for (final k in TeamEntryKind.values)
              DropdownMenuItem(
                value: k,
                child: Row(
                  children: [
                    Icon(
                      teamKindIcon(k),
                      size: 16,
                      color: teamKindColor(k, luma),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        teamKindLabel(t, k),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (k) => setState(() => _kind = k ?? _kind),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<TeamForumRequire>(
          key: const ValueKey('team-discord-require'),
          isExpanded: true,
          initialValue: _require,
          decoration: _fieldDecoration(t.teamDiscordRequireLabel),
          items: [
            for (final r in TeamForumRequire.values)
              DropdownMenuItem(
                value: r,
                child: Text(
                  _requireLabel(t, r),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (r) => setState(() => _require = r ?? _require),
        ),
        if (_require != TeamForumRequire.none) ...[
          const SizedBox(height: 28),
          _ForumReplyField(
            label: t.teamDiscordMissingLabel,
            hint: t.teamDiscordMissingHint,
            child: TextField(
              key: const ValueKey('team-discord-missing'),
              controller: _missing,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              style: const TextStyle(fontSize: 14, height: 1.5),
              decoration: _fieldDecoration(null),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _ForumReplyField(
          label: t.teamDiscordDoneLabel,
          hint: t.teamDiscordDoneHint('{status}'),
          child: TextField(
            key: const ValueKey('team-discord-done'),
            controller: _done,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: _fieldDecoration(null),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String? label) {
    final luma = context.luma;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: luma.border),
    );
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: luma.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: luma.accent, width: 2),
      ),
    );
  }
}

class _ForumReplyField extends StatelessWidget {
  const _ForumReplyField({
    required this.label,
    required this.hint,
    required this.child,
  });

  final String label;
  final String hint;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: TextStyle(
          color: context.luma.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        hint,
        style: TextStyle(
          color: context.luma.textSecondary,
          fontSize: 12,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 12),
      child,
    ],
  );
}
