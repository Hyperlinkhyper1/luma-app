import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../creature/creature_model.dart';
import '../creature/creature_physics.dart';
import '../creature/creature_presets.dart';
import '../creature/creature_skin.dart';
import '../creature/evolution.dart';
import '../creature/shape_skeleton.dart';
import 'drawing_board.dart';
import 'fitness_chart.dart';
import 'walk_view.dart';

/// Draw a shape, watch it learn to walk 50 metres.
///
/// Three panels, in the order the thing actually happens: the drawing becomes
/// a skeleton, the skeleton gets a gait bred for it, and the graph shows the
/// breeding working. Everything runs on this device; the population is
/// evaluated in background isolates so the walk stays at frame rate.
class CreatureLabTab extends StatefulWidget {
  const CreatureLabTab({super.key});

  @override
  State<CreatureLabTab> createState() => _CreatureLabTabState();
}

class _CreatureLabTabState extends State<CreatureLabTab>
    with SingleTickerProviderStateMixin {
  static const _wideBreakpoint = 1040.0;

  final List<List<Offset>> _strokes = [];
  List<Offset>? _draft;

  CreatureShape? _shape;
  CreatureSkin? _skin;
  EvolutionSession? _session;
  CreatureSim? _sim;

  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _lastTick = Duration.zero;

  int _watching = 0;
  bool _follow = true;
  bool _showSkin = true;
  double _speed = 4;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _session?.removeListener(_onGeneration);
    _session?.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ─── Drawing ──────────────────────────────────────────────────────────────

  void _startStroke(Offset point) => setState(() => _draft = [point]);

  void _extendStroke(Offset point) {
    final draft = _draft;
    if (draft == null) return;
    if (draft.isNotEmpty && (draft.last - point).distance < 0.004) return;
    setState(() => draft.add(point));
  }

  void _finishStroke() {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      if (draft.length >= 2) _strokes.add(List<Offset>.from(draft));
      _draft = null;
    });
    _rebuild();
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(_strokes.removeLast);
    _rebuild();
  }

  void _clear() {
    if (_strokes.isEmpty && _shape == null) return;
    setState(() {
      _strokes.clear();
      _draft = null;
    });
    _rebuild();
  }

  void _usePreset(CreaturePreset preset) {
    setState(() {
      _strokes
        ..clear()
        ..addAll([for (final s in preset.strokes) List<Offset>.from(s)]);
      _draft = null;
    });
    _rebuild();
  }

  // ─── The run ──────────────────────────────────────────────────────────────

  /// Any change to the drawing is a different animal, so the search starts
  /// over from noise rather than carrying a gait bred for another body.
  void _rebuild() {
    _session?.removeListener(_onGeneration);
    _session?.dispose();
    _session = null;
    _sim = null;
    _skin = null;
    _watching = 0;
    _follow = true;

    final shape = _strokes.isEmpty ? null : ShapeSkeleton.build(_strokes);
    setState(() => _shape = shape);
    if (shape == null) return;

    _skin = CreatureSkin.bind(shape);
    _session = EvolutionSession(shape: shape)
      ..addListener(_onGeneration)
      ..start();
    _replay(_restingGenes(shape));
  }

  /// A body that has not been bred yet just stands there, so the viewport is
  /// never empty while generation one is being evaluated.
  static Float64List _restingGenes(CreatureShape shape) {
    final genes = Float64List(shape.geneCount);
    for (var i = 0; i < genes.length; i++) {
      genes[i] = 0.5;
    }
    genes[0] = 0;
    for (var j = 0; j < shape.jointCount; j++) {
      genes[1 + j * 3] = 0;
    }
    return genes;
  }

  void _onGeneration() {
    final session = _session;
    if (session == null || !mounted) return;
    if (_follow) _watching = session.generation - 1;
    setState(() {});
  }

  void _replay(Float64List genes) {
    final shape = _shape;
    if (shape == null) return;
    _sim = CreatureSim(shape, genes, config: const TrialConfig());
    _frame.value++;
  }

  void _watch(int generation) {
    final session = _session;
    if (session == null || session.history.isEmpty) return;
    final index = generation.clamp(0, session.history.length - 1);
    setState(() {
      _watching = index;
      _follow = index == session.history.length - 1;
    });
    _replay(session.history[index].championGenes);
  }

  void _onTick(Duration elapsed) {
    final delta = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final sim = _sim;
    if (sim == null) return;

    if (sim.done) {
      final session = _session;
      if (session != null && session.history.isNotEmpty) {
        if (_follow) _watching = session.history.length - 1;
        _replay(session.history[_watching.clamp(0, session.history.length - 1)]
            .championGenes);
      }
      return;
    }

    // Cap the catch-up so a dropped frame cannot turn into a long stall.
    final steps = (delta.clamp(0.0, 0.1) * _speed / sim.config.dt).round();
    for (var i = 0; i < steps && !sim.done; i++) {
      sim.step();
    }
    _frame.value++;
  }

  // ─── Layout ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _drawPanel(),
                const SizedBox(height: 12),
                _walkPanel(viewportHeight: 220),
                const SizedBox(height: 12),
                _chartPanel(chartHeight: 160),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 340,
                child: SingleChildScrollView(child: _drawPanel()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _walkPanel()),
                    const SizedBox(height: 16),
                    Expanded(flex: 2, child: _chartPanel()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _drawPanel() {
    final luma = context.luma;
    final shape = _shape;
    return LumaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            step: '1',
            title: 'Draw your creature',
            trailing: shape == null
                ? (_strokes.isEmpty ? null : 'too small')
                : 'skeleton found',
            trailingColor: shape == null ? luma.warning : luma.success,
          ),
          const SizedBox(height: 12),
          DrawingBoard(
            strokes: _strokes,
            draft: _draft,
            shape: shape,
            onStart: _startStroke,
            onExtend: _extendStroke,
            onFinish: _finishStroke,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LumaGhostButton(
                  label: 'Undo',
                  icon: Icons.undo_rounded,
                  onTap: _strokes.isEmpty ? null : _undo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LumaGhostButton(
                  label: 'Clear',
                  icon: Icons.delete_outline_rounded,
                  onTap: _strokes.isEmpty ? null : _clear,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'START FROM AN EXAMPLE',
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final preset in CreaturePreset.all)
                _PresetChip(
                  label: preset.name,
                  onTap: () => _usePreset(preset),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Stat(label: 'Bodies', value: '${shape?.boneCount ?? 0}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(label: 'Joints', value: '${shape?.jointCount ?? 0}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Stat(label: 'Genes', value: '${shape?.geneCount ?? 0}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Each stroke is closed and merged into one body. The medial axis '
            'of that body becomes the bones — lavender capsules, green joints, '
            'amber head. Redrawing starts the search again from scratch.',
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// [viewportHeight] is null on wide screens, where the panel fills whatever
  /// the row gives it. On a phone the panel sizes to its content instead —
  /// the controls wrap onto several rows there, and a fixed panel height would
  /// leave the viewport nothing.
  Widget _walkPanel({double? viewportHeight}) {
    final luma = context.luma;
    final shape = _shape;
    final sim = _sim;
    final skin = _skin;
    final session = _session;
    final viewport = shape == null || sim == null || skin == null
        ? _EmptyViewport(luma: luma)
        : Stack(
            children: [
              Positioned.fill(
                child: WalkView(
                  shape: shape,
                  sim: sim,
                  skin: skin,
                  repaint: _frame,
                  showSkin: _showSkin,
                ),
              ),
              Positioned(
                left: 12,
                top: 10,
                child: ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, _, _) => _WalkHud(sim: sim, luma: luma),
                ),
              ),
            ],
          );
    return LumaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize:
            viewportHeight == null ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            step: '2',
            title: 'The walk to 50 metres',
            trailing: session == null
                ? null
                : 'generation ${_watching + 1} of ${session.generation}',
            trailingColor: luma.textSecondary,
          ),
          const SizedBox(height: 10),
          if (viewportHeight == null)
            Expanded(child: viewport)
          else
            SizedBox(height: viewportHeight, child: viewport),
          if (session != null) ...[
            const SizedBox(height: 12),
            _controls(session),
          ],
        ],
      ),
    );
  }

  Widget _controls(EvolutionSession session) {
    final luma = context.luma;
    final best = session.bestEver;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 168,
              child: LumaPrimaryButton(
                label: session.running ? 'Pause evolution' : 'Resume evolution',
                icon: session.running
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: () => setState(session.toggle),
              ),
            ),
            SizedBox(
              width: 120,
              child: LumaGhostButton(
                label: 'Restart',
                icon: Icons.restart_alt_rounded,
                onTap: _rebuild,
              ),
            ),
            _SpeedControl(
              value: _speed,
              onChanged: (v) => setState(() => _speed = v),
            ),
            _SkinToggle(
              value: _showSkin,
              onChanged: (v) => setState(() => _showSkin = v),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _WatchGenerationRow(
          label: Text(
            'Watch generation',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
          slider: Slider(
            value: _watching
                .clamp(0, session.history.isEmpty ? 0 : session.history.length - 1)
                .toDouble(),
            min: 0,
            max: session.history.isEmpty
                ? 0
                : (session.history.length - 1).toDouble(),
            onChanged:
                session.history.length < 2 ? null : (v) => _watch(v.round()),
          ),
          follow: _FollowToggle(
            value: _follow,
            onChanged: (v) {
              setState(() => _follow = v);
              if (v) _watch(session.history.length - 1);
            },
          ),
        ),
        const SizedBox(height: 4),
        DefaultTextStyle(
          style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.45),
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text('Generation ${session.generation}'),
              if (best != null)
                Text(
                  'best ${best.champion.distance.toStringAsFixed(1)} m '
                  '(gen ${best.index + 1})',
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text('${session.generationsPerSecond.toStringAsFixed(1)} gen/s'),
              Text('${session.workerCount} workers'),
              if (best != null && best.champion.finished)
                Text(
                  'reached 50 m in ${best.champion.finishSeconds.toStringAsFixed(1)} s',
                  style: TextStyle(
                    color: luma.success,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chartPanel({double? chartHeight}) {
    final luma = context.luma;
    final session = _session;
    final chart = FitnessChart(
      history: session?.history ?? const [],
      selected: _watching,
      onScrub: _watch,
    );
    return LumaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize:
            chartHeight == null ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _PanelHeader(
                  step: '3',
                  title: 'Fitness over generations',
                ),
              ),
              _LegendKey(color: luma.accent, label: 'Best', dashed: false),
              const SizedBox(width: 10),
              _LegendKey(
                color: luma.textSecondary,
                label: 'Average',
                dashed: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (chartHeight == null)
            Expanded(child: chart)
          else
            SizedBox(height: chartHeight, child: chart),
          const SizedBox(height: 6),
          Text(
            session == null
                ? 'Draw a creature to start the search.'
                : 'Tap the graph to watch any generation walk again.',
            style: TextStyle(color: luma.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

// ─── Small pieces ───────────────────────────────────────────────────────────

/// Label, scrubber and follow toggle on one line when there is room for it,
/// and stacked when there is not — a slider squeezed between two labels on a
/// phone ends up too small to hit.
class _WatchGenerationRow extends StatelessWidget {
  const _WatchGenerationRow({
    required this.label,
    required this.slider,
    required this.follow,
  });

  final Widget label;
  final Widget slider;
  final Widget follow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 460) {
          return Row(
            children: [label, Expanded(child: slider), follow],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Flexible(child: label), Flexible(child: follow)],
            ),
            slider,
          ],
        );
      },
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.step,
    required this.title,
    this.trailing,
    this.trailingColor,
  });

  final String step;
  final String title;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: luma.accentSubtle,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            step,
            style: TextStyle(
              color: luma.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              color: trailingColor ?? luma.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 9,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: luma.background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: luma.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyViewport extends StatelessWidget {
  const _EmptyViewport({required this.luma});
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_walk_rounded,
                color: luma.textMuted,
                size: 30,
              ),
              const SizedBox(height: 10),
              Text(
                'Nothing to walk yet',
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Draw a body on the left and the search starts on its own.',
                textAlign: TextAlign.center,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalkHud extends StatelessWidget {
  const _WalkHud({required this.sim, required this.luma});
  final CreatureSim sim;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    final numbers = TextStyle(
      color: luma.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final captions = TextStyle(
      color: luma.textMuted,
      fontSize: 9,
      letterSpacing: 0.7,
      fontWeight: FontWeight.w700,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: luma.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DISTANCE', style: captions),
              Text('${sim.distance.toStringAsFixed(2)} m', style: numbers),
            ],
          ),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TIME', style: captions),
              Text(
                '${sim.time.toStringAsFixed(1)} / '
                '${sim.config.seconds.toStringAsFixed(0)} s',
                style: numbers,
              ),
            ],
          ),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HEAD DOWN', style: captions),
              Text(
                '${sim.headDownSeconds.toStringAsFixed(1)} s',
                style: numbers.copyWith(
                  color: sim.headDownSeconds > 0.05
                      ? luma.warning
                      : luma.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedControl extends StatelessWidget {
  const _SpeedControl({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SizedBox(
      width: 210,
      child: Row(
        children: [
          Text(
            'Speed',
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: 1,
              max: 16,
              divisions: 15,
              label: '${value.round()}x',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '${value.round()}x',
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkinToggle extends StatelessWidget {
  const _SkinToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CheckRow(
      label: 'Show drawing',
      value: value,
      onChanged: onChanged,
    );
  }
}

class _FollowToggle extends StatelessWidget {
  const _FollowToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _CheckRow(
      label: 'Follow latest',
      value: value,
      onChanged: onChanged,
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendKey extends StatelessWidget {
  const _LegendKey({
    required this.color,
    required this.label,
    required this.dashed,
  });
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 3,
          child: Row(
            children: dashed
                ? [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(child: ColoredBox(color: color)),
                    ],
                  ]
                : [Expanded(child: ColoredBox(color: color))],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: luma.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
