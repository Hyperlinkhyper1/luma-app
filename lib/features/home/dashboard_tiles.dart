import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/nav_rail.dart';
import '../../theme/luma_theme.dart';
import '../../finance/finance_scope.dart';
import '../../finance/logic/finance_logic.dart';
import '../../finance/logic/money.dart';
import '../../settings/settings_scope.dart';
import '../notes/notes_repository.dart';
import '../plugins/plugin_scope.dart';
import '../plugins/installed/calculator/calc_expression.dart';
import '../plugins/installed/errands/errands_scope.dart';
import '../plugins/installed/errands/errands_repository.dart';
import '../plugins/installed/minecraft_launcher/minecraft_launcher_scope.dart';
import '../plugins/installed/minecraft_launcher/data/minecraft_launcher_database.dart';
import '../plugins/installed/minecraft_launcher/logic/active_launch_registry.dart';
import '../plugins/installed/minecraft_launcher/ui/download_progress_sheet.dart';
import 'home_layout.dart';
import 'dashboard_connected_tiles.dart';
import 'home_classic_tiles.dart';

String? _configString(Map<String, dynamic> config, String key) =>
    config[key] is String ? config[key] as String : null;

int _configMinutes(Map<String, dynamic> config) {
  final value = config['minutes'];
  return value is num && value.isFinite ? value.clamp(1, 1440).toInt() : 25;
}

class DashboardTileDefinition {
  const DashboardTileDefinition(
    this.kind,
    this.title,
    this.icon,
    this.defaultWidth,
    this.defaultHeight,
  );
  final String kind;
  final String title;
  final IconData icon;
  final int defaultWidth;
  final int defaultHeight;
}

const dashboardTileDefinitions = [
  DashboardTileDefinition(
    'income',
    'Came in this month',
    Icons.south_west_rounded,
    6,
    2,
  ),
  DashboardTileDefinition(
    'spending',
    'Went out this month',
    Icons.north_east_rounded,
    6,
    2,
  ),
  DashboardTileDefinition(
    'pots',
    'Set aside in pots',
    Icons.savings_rounded,
    6,
    2,
  ),
  DashboardTileDefinition(
    'investments',
    'Investments',
    Icons.trending_up_rounded,
    6,
    2,
  ),
  DashboardTileDefinition(
    'shortcut',
    'App shortcut',
    Icons.arrow_outward_rounded,
    3,
    3,
  ),
  DashboardTileDefinition(
    'recent_activity',
    'Recent activity',
    Icons.history_rounded,
    12,
    5,
  ),
  DashboardTileDefinition(
    'finance',
    'Finance overview',
    Icons.account_balance_wallet_outlined,
    6,
    5,
  ),
  DashboardTileDefinition(
    'note',
    'Pinned note',
    Icons.sticky_note_2_outlined,
    6,
    5,
  ),
  DashboardTileDefinition(
    'plugin',
    'Plugin shortcut',
    Icons.extension_outlined,
    3,
    3,
  ),
  DashboardTileDefinition(
    'minecraft',
    'Minecraft instance',
    Icons.sports_esports_outlined,
    4,
    4,
  ),
  DashboardTileDefinition('errands', 'Errands', Icons.checklist_rounded, 4, 5),
  DashboardTileDefinition(
    'stocks',
    'Stock chart',
    Icons.show_chart_rounded,
    6,
    5,
  ),
  DashboardTileDefinition(
    'github_graph',
    'GitHub activity',
    Icons.grid_on_rounded,
    6,
    4,
  ),
  DashboardTileDefinition(
    'github_issues',
    'GitHub issues',
    Icons.adjust_rounded,
    6,
    5,
  ),
  DashboardTileDefinition(
    'ai_usage',
    'AI usage',
    Icons.auto_awesome_outlined,
    4,
    4,
  ),
  DashboardTileDefinition(
    'calculator',
    'Calculator',
    Icons.calculate_outlined,
    4,
    5,
  ),
  DashboardTileDefinition(
    'clock',
    'Clock & date',
    Icons.schedule_rounded,
    4,
    3,
  ),
  DashboardTileDefinition('timer', 'Focus timer', Icons.timer_outlined, 4, 5),
  DashboardTileDefinition(
    'quick_links',
    'Quick actions',
    Icons.bolt_rounded,
    4,
    4,
  ),
];

Future<HomeTile?> configureDashboardTile(
  BuildContext context,
  HomeTile tile,
) async {
  final config = Map<String, dynamic>.from(tile.config);
  if (tile.kind == 'shortcut') {
    final destination = await _pick(context, 'Choose a shortcut', {
      '5': 'Ask Assistant',
      '2': 'Finance',
      '1': 'File Converter',
      '4': 'Notes',
      '3': 'Passwords',
      '6': 'Plugins',
      '7': 'Settings',
    }, '');
    if (destination == null) return null;
    config['destination'] = int.parse(destination);
  } else if (tile.kind == 'note') {
    final notes = NotesRepository.instance.notes;
    final id = await _pick(context, 'Choose a note', {
      for (final n in notes) n.id: n.title.isEmpty ? 'Untitled note' : n.title,
    }, 'Create a note in Notes first.');
    if (id == null) return null;
    config['noteId'] = id;
  } else if (tile.kind == 'plugin') {
    final plugins = await PluginScope.of(context).watchInstalled().first;
    if (!context.mounted) return null;
    final id = await _pick(context, 'Choose a plugin', {
      for (final p in plugins) p.pluginId: p.name,
    }, 'Install a plugin from the marketplace first.');
    if (id == null) return null;
    config['pluginId'] = id;
  } else if (tile.kind == 'minecraft') {
    final instances = await MinecraftLauncherScope.of(
      context,
    ).watchInstances().first;
    if (!context.mounted) return null;
    final id = await _pick(
      context,
      'Choose an instance',
      {for (final i in instances) i.id: '${i.name} · ${i.versionId}'},
      'Create an instance in Minecraft Launcher first.',
    );
    if (id == null) return null;
    config['instanceId'] = id;
    final instance = instances.firstWhere((instance) => instance.id == id);
    config['instanceName'] = instance.name;
    config['instanceVersion'] = instance.versionId;
    config['instanceLoader'] = instance.loader;
  } else if (tile.kind == 'stocks' ||
      tile.kind == 'github_issues' ||
      tile.kind == 'timer') {
    final key = tile.kind == 'stocks'
        ? 'symbol'
        : tile.kind == 'timer'
        ? 'minutes'
        : 'repository';
    final label = tile.kind == 'stocks'
        ? 'Stock symbol (blank for all holdings)'
        : tile.kind == 'timer'
        ? 'Timer minutes (1–1440)'
        : 'Repository: owner/name (blank for all)';
    final value = await _input(
      context,
      label,
      '${config[key] ?? (key == 'minutes' ? 25 : '')}',
      numeric: key == 'minutes',
    );
    if (value == null) return null;
    config[key] = key == 'minutes'
        ? (int.tryParse(value) ?? 25).clamp(1, 1440)
        : value.trim();
  }
  return tile.copyWith(config: config);
}

Future<String?> _pick(
  BuildContext context,
  String title,
  Map<String, String> options,
  String empty,
) => showDialog<String>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(title),
    children: options.isEmpty
        ? [Padding(padding: const EdgeInsets.all(24), child: Text(empty))]
        : options.entries
              .map(
                (e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, e.key),
                  child: Text(e.value),
                ),
              )
              .toList(),
  ),
);

Future<String?> _input(
  BuildContext context,
  String label,
  String initial, {
  bool numeric = false,
}) async {
  var input = initial;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(label),
      content: TextFormField(
        initialValue: initial,
        onChanged: (value) => input = value,
        autofocus: true,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        onFieldSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, input),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  return result;
}

class DashboardTileContent extends StatelessWidget {
  const DashboardTileContent({
    super.key,
    required this.tile,
    required this.onNavigate,
    required this.onPlugin,
    this.editing = false,
  });
  final HomeTile tile;
  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onPlugin;

  /// Tiles that draw their own badge and label hand it back to the grid's
  /// header while the layout is being edited.
  final bool editing;
  @override
  Widget build(BuildContext context) {
    final child = switch (tile.kind) {
      'income' ||
      'spending' ||
      'pots' ||
      'investments' => HomeClassicMetric(kind: tile.kind, editing: editing),
      'recent_activity' => const HomeRecentActivity(),
      'shortcut' => HomeClassicShortcut(
        destination: tile.config['destination'] is int
            ? tile.config['destination'] as int
            : 5,
        onNavigate: onNavigate,
        editing: editing,
      ),
      'finance' => const _FinanceTile(),
      'note' => _NoteTile(id: _configString(tile.config, 'noteId')),
      'plugin' => _PluginTile(
        id: _configString(tile.config, 'pluginId'),
        onPlugin: onPlugin,
      ),
      'minecraft' => _MinecraftTile(
        id: _configString(tile.config, 'instanceId'),
        name: _configString(tile.config, 'instanceName'),
        version: _configString(tile.config, 'instanceVersion'),
        loader: _configString(tile.config, 'instanceLoader'),
      ),
      'errands' => const _ErrandsTile(),
      'stocks' => DashboardStocksTile(
        symbol: _configString(tile.config, 'symbol'),
      ),
      'github_graph' => const DashboardGithubTile(issues: false),
      'github_issues' => DashboardGithubTile(
        issues: true,
        repository: _configString(tile.config, 'repository'),
      ),
      'ai_usage' => const DashboardAiUsageTile(),
      'calculator' => const _CalculatorTile(),
      'clock' => const _ClockTile(),
      'timer' => _TimerTile(id: tile.id, minutes: _configMinutes(tile.config)),
      'quick_links' => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in const {
            1: 'Convert files',
            2: 'Finances',
            3: 'Passwords',
            5: 'Assistant',
            NavRail.settingsIndex: 'Settings',
          }.entries)
            ActionChip(
              label: Text(entry.value),
              onPressed: () => onNavigate(entry.key),
            ),
        ],
      ),
      _ => const Text('This tile is not available in this version.'),
    };
    final pluginId = switch (tile.kind) {
      'minecraft' => 'minecraft-launcher',
      'errands' => 'errand-manager',
      'calculator' => 'calculator',
      'github_graph' || 'github_issues' => 'account-overview',
      'ai_usage' => 'ai-usage',
      _ => null,
    };
    if (pluginId == null) return child;
    return StreamBuilder(
      stream: PluginScope.of(context).watchInstalled(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Could not load installed plugins.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.data!.any((p) => p.pluginId == pluginId)) {
          return Text(
            'Install ${pluginId.replaceAll('_', ' ')} to use this tile.',
          );
        }
        return child;
      },
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({this.id});
  final String? id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: NotesRepository.instance,
    builder: (context, _) {
      final matches = NotesRepository.instance.notes.where((n) => n.id == id);
      if (matches.isEmpty) {
        return const Text(
          'Choose a note using this tile’s settings. Notes must be synced separately to appear on another device.',
        );
      }
      final note = matches.first;
      final lines = note.content.split('\n');
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          Text(
            note.title.isEmpty ? 'Untitled note' : note.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < lines.length; i++) _noteLine(note, lines, i),
        ],
      );
    },
  );
  Widget _noteLine(Note note, List<String> lines, int index) {
    final match = RegExp(r'^(?:- )?\[( |x|X)\] (.*)$').firstMatch(lines[index]);
    if (match == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(lines[index]),
      );
    }
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(match.group(2)!),
      value: match.group(1) != ' ',
      onChanged: (checked) {
        final latest = NotesRepository.instance.notes
            .where((n) => n.id == note.id)
            .firstOrNull;
        if (latest == null || latest.content != note.content) return;
        lines[index] =
            '${lines[index].startsWith('- ') ? '- ' : ''}[${checked == true ? 'x' : ' '}] ${match.group(2)}';
        NotesRepository.instance.update(note.id, content: lines.join('\n'));
      },
    );
  }
}

class _PluginTile extends StatelessWidget {
  const _PluginTile({this.id, required this.onPlugin});
  final String? id;
  final ValueChanged<String> onPlugin;
  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: PluginScope.of(context).watchInstalled(),
    builder: (context, snapshot) {
      final plugin = snapshot.data?.where((p) => p.pluginId == id).firstOrNull;
      if (plugin == null) {
        return const Text('Choose an installed plugin in tile settings.');
      }
      return Center(
        child: FilledButton.tonalIcon(
          onPressed: () => onPlugin(plugin.pluginId),
          icon: const Icon(Icons.arrow_outward_rounded),
          label: Text(plugin.name),
        ),
      );
    },
  );
}

class _ErrandsTile extends StatelessWidget {
  const _ErrandsTile();
  @override
  Widget build(BuildContext context) {
    final repo = ErrandsScope.of(context);
    return StreamBuilder<List<ErrandRecord>>(
      stream: repo.watchErrands(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Could not load errands.');
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final errands = snapshot.data!;
        if (errands.isEmpty) {
          return const Text('Add your recurring tasks in the Errands plugin.');
        }
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            for (final e in errands)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: e.wasDoneOn(DateTime.now()),
                title: Text(e.name),
                subtitle: Text(
                  e.isDueOn(DateTime.now())
                      ? 'Due today'
                      : '${e.nextDue.day}/${e.nextDue.month} · ${e.repeatLabel}',
                ),
                onChanged: (done) async {
                  try {
                    if (done == true) {
                      await repo.complete(e);
                    } else {
                      await repo.uncomplete(e);
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not update errand: $error'),
                        ),
                      );
                    }
                  }
                },
              ),
          ],
        );
      },
    );
  }
}

class _MinecraftTile extends StatefulWidget {
  const _MinecraftTile({this.id, this.name, this.version, this.loader});
  final String? id;
  final String? name, version, loader;
  @override
  State<_MinecraftTile> createState() => _MinecraftTileState();
}

class _MinecraftTileState extends State<_MinecraftTile> {
  bool _busy = false;
  Future<void> _play(McInstance instance) async {
    final repo = MinecraftLauncherScope.of(context);
    setState(() => _busy = true);
    int? launchId;
    try {
      final account = await repo.watchActiveAccount().first;
      if (!mounted) return;
      if (account == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add an account in Minecraft Launcher first.'),
          ),
        );
        return;
      }
      launchId = await repo.recordLaunchStart(instance.id);
      if (!mounted) {
        await repo.recordLaunchEnd(launchId, exitCode: -1);
        return;
      }
      final handle = await showDownloadProgressAndLaunch(
        context,
        instance: instance,
        account: account,
      );
      if (handle == null) {
        await repo.recordLaunchEnd(launchId, exitCode: -1);
        return;
      }
      ActiveLaunchRegistry.instance.register(instance.id, handle);
      await repo.markLaunched(instance.id);
      final completedLaunchId = launchId;
      unawaited(
        handle.exitCode.then(
          (code) => repo.recordLaunchEnd(
            completedLaunchId,
            exitCode: code,
            logFilePath: handle.logFilePath,
          ),
        ),
      );
    } catch (error) {
      if (launchId != null) await repo.recordLaunchEnd(launchId, exitCode: -1);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Launch failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: MinecraftLauncherScope.of(context).watchInstances(),
    builder: (context, snapshot) {
      var instance = snapshot.data?.where((i) => i.id == widget.id).firstOrNull;
      if (instance == null &&
          widget.name != null &&
          widget.version != null &&
          widget.loader != null) {
        final matches = snapshot.data
            ?.where(
              (i) =>
                  i.name == widget.name &&
                  i.versionId == widget.version &&
                  i.loader == widget.loader,
            )
            .toList();
        if (matches?.length == 1) instance = matches!.single;
      }
      final selected = instance;
      if (selected == null) {
        return const Text(
          'Choose an instance available on this device in tile settings.',
        );
      }
      return ListenableBuilder(
        listenable: ActiveLaunchRegistry.instance,
        builder: (context, _) {
          final running = ActiveLaunchRegistry.instance.isRunning(selected.id);
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('${selected.versionId} · ${selected.loader}'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || running ? null : () => _play(selected),
                  icon: Icon(
                    running ? Icons.sports_esports : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    _busy
                        ? 'Preparing…'
                        : running
                        ? 'Running'
                        : 'Play now',
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _CalculatorTile extends StatefulWidget {
  const _CalculatorTile();
  @override
  State<_CalculatorTile> createState() => _CalculatorTileState();
}

class _CalculatorTileState extends State<_CalculatorTile> {
  final _input = TextEditingController();
  String _result = '0';
  double _answer = 0;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _calculate() {
    setState(() {
      try {
        _answer = CalcExpression.evaluateOnce(_input.text, ans: _answer);
        _result = formatCalcNumber(_answer);
      } catch (error) {
        _result = '$error';
      }
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _input,
          decoration: const InputDecoration(
            hintText: 'e.g. (42 + 8) / 2',
            isDense: true,
          ),
          onSubmitted: (_) => _calculate(),
        ),
        const SizedBox(height: 12),
        SelectableText(
          _result,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
            color: context.luma.accent,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final key in [
              '7',
              '8',
              '9',
              '/',
              '4',
              '5',
              '6',
              '*',
              '1',
              '2',
              '3',
              '-',
              '0',
              '.',
              '(',
              ')',
              '+',
              'ans',
            ])
              SizedBox(
                width: 42,
                height: 34,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () {
                    final selection = _input.selection;
                    final start = selection.isValid
                        ? selection.start
                        : _input.text.length;
                    final end = selection.isValid ? selection.end : start;
                    _input.value = TextEditingValue(
                      text: _input.text.replaceRange(start, end, key),
                      selection: TextSelection.collapsed(
                        offset: start + key.length,
                      ),
                    );
                  },
                  child: Text(key),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () {
                _input.clear();
                setState(() => _result = '0');
              },
              child: const Text('Clear'),
            ),
            const Spacer(),
            FilledButton(onPressed: _calculate, child: const Text('=')),
          ],
        ),
      ],
    ),
  );
}

class _ClockTile extends StatefulWidget {
  const _ClockTile();
  @override
  State<_ClockTile> createState() => _ClockTileState();
}

class _ClockTileState extends State<_ClockTile> {
  late final Timer _ticker;
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay.fromDateTime(now),
              alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                context,
              ),
            ),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              color: context.luma.accent,
            ),
          ),
          Text(MaterialLocalizations.of(context).formatFullDate(now)),
          const SizedBox(height: 4),
          Text(now.timeZoneName, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _TimerRuntime {
  _TimerRuntime(this.minutes) : remaining = minutes * 60;
  int minutes;
  int remaining;
  DateTime? deadline;
  Timer? _alarm;

  void refresh() {
    if (deadline == null) return;
    remaining = (deadline!.difference(DateTime.now()).inMilliseconds / 1000)
        .ceil()
        .clamp(0, 86400);
    if (remaining == 0) {
      _alarm?.cancel();
      deadline = null;
      SystemSound.play(SystemSoundType.alert);
    }
  }

  void reset(int durationMinutes) {
    _alarm?.cancel();
    minutes = durationMinutes;
    remaining = minutes * 60;
    deadline = null;
  }

  void toggle() {
    refresh();
    if (deadline != null) {
      _alarm?.cancel();
      deadline = null;
    } else {
      if (remaining == 0) reset(minutes);
      deadline = DateTime.now().add(Duration(seconds: remaining));
      _alarm = Timer(Duration(seconds: remaining), () {
        remaining = 0;
        deadline = null;
        SystemSound.play(SystemSoundType.alert);
      });
    }
  }
}

final _timerRuntimes = <String, _TimerRuntime>{};

class _TimerTile extends StatefulWidget {
  const _TimerTile({required this.id, required this.minutes});
  final String id;
  final int minutes;
  @override
  State<_TimerTile> createState() => _TimerTileState();
}

class _TimerTileState extends State<_TimerTile> {
  late final Timer _ticker;
  late _TimerRuntime _runtime;
  int? _lastRemaining;
  @override
  void initState() {
    super.initState();
    _attach();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted &&
          (_runtime.deadline != null || _lastRemaining != _runtime.remaining)) {
        setState(() {
          _runtime.refresh();
          _lastRemaining = _runtime.remaining;
        });
      }
    });
  }

  void _attach() {
    _runtime = _timerRuntimes.putIfAbsent(
      widget.id,
      () => _TimerRuntime(widget.minutes.clamp(1, 1440)),
    );
    if (_runtime.minutes != widget.minutes) {
      _runtime.reset(widget.minutes.clamp(1, 1440));
    }
    _runtime.refresh();
  }

  @override
  void didUpdateWidget(_TimerTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id || widget.minutes != oldWidget.minutes) {
      _attach();
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${(_runtime.remaining ~/ 60).toString().padLeft(2, '0')}:${(_runtime.remaining % 60).toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            color: context.luma.accent,
          ),
        ),
        Text(
          _runtime.remaining == 0
              ? 'Time is up. Take a breath.'
              : 'A little space to focus.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => setState(_runtime.toggle),
              icon: Icon(
                _runtime.deadline == null ? Icons.play_arrow : Icons.pause,
              ),
              label: Text(_runtime.deadline == null ? 'Start' : 'Pause'),
            ),
            TextButton(
              onPressed: () => setState(() => _runtime.reset(widget.minutes)),
              child: const Text('Reset'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FinanceTile extends StatelessWidget {
  const _FinanceTile();
  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    final hide = SettingsScope.of(context).hideAmounts;
    return StreamBuilder(
      stream: repo.watchTransactions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('Could not load finances.');
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final balances = computeBalances(snapshot.data!);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AVAILABLE BALANCE',
                style: TextStyle(
                  color: context.luma.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hide ? '••••••' : formatCents(balances.mainCents),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  color: context.luma.accent,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'In pots  ${hide ? '••••••' : formatCents(balances.potsTotalCents)}',
              ),
              Text(
                'Total cash  ${hide ? '••••••' : formatCents(balances.totalCents)}',
              ),
            ],
          ),
        );
      },
    );
  }
}
