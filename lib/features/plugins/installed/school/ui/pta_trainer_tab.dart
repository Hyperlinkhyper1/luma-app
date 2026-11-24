import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../logic/pta/pta_chemistry.dart';
import '../logic/pta/pta_lab.dart';
import '../logic/pta/pta_scenarios.dart';
import 'pta/pta_lab_view.dart';
import 'pta/pta_result_view.dart';

/// PTA trainer: practise the school exam "practicum kwalitatieve analyse" —
/// one jar, four candidate substances, a virtual lab to find out which.
class PtaTrainerTab extends StatefulWidget {
  const PtaTrainerTab({super.key, this.random});

  /// Seedable for tests.
  final math.Random? random;

  @override
  State<PtaTrainerTab> createState() => _PtaTrainerTabState();
}

enum _Phase { setup, lab, result }

class _PtaTrainerTabState extends State<PtaTrainerTab> {
  late final math.Random _rng = widget.random ?? math.Random();
  _Phase _phase = _Phase.setup;
  Level _level = Level.vwo;
  bool _exam = false;

  /// Null picks a random set.
  String? _setId;
  PtaSet? _set;
  PtaLab? _lab;
  Substance? _choice;

  void _start({bool sameSet = false}) {
    final PtaSet set;
    if (sameSet && _set != null) {
      set = _set!.id == 'random' ? randomSet(_level, _rng) : _set!;
    } else if (_setId == null) {
      set = randomSet(_level, _rng);
    } else {
      set = ptaSets.firstWhere((s) => s.id == _setId);
    }
    final candidates = set.candidates;
    setState(() {
      _set = set;
      _lab = PtaLab(candidates[_rng.nextInt(candidates.length)]);
      _choice = null;
      _phase = _Phase.lab;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (_phase) {
        _Phase.setup => _SetupView(
            key: const ValueKey('pta-setup'),
            level: _level,
            exam: _exam,
            setId: _setId,
            onLevel: (l) => setState(() {
              _level = l;
              if (_setId != null &&
                  !setsFor(l).any((s) => s.id == _setId)) {
                _setId = null;
              }
            }),
            onExam: (e) => setState(() => _exam = e),
            onSet: (id) => setState(() => _setId = id),
            onStart: _start,
          ),
        _Phase.lab => PtaLabView(
            key: ValueKey(_lab),
            lab: _lab!,
            set: _set!,
            exam: _exam,
            onHandIn: (c) => setState(() {
              _choice = c;
              _phase = _Phase.result;
            }),
            onQuit: () => setState(() => _phase = _Phase.setup),
          ),
        _Phase.result => PtaResultView(
            key: ValueKey('result-${_lab.hashCode}'),
            lab: _lab!,
            set: _set!,
            choice: _choice!,
            onSameSet: () => _start(sameSet: true),
            onNew: () => setState(() => _phase = _Phase.setup),
          ),
      },
    );
  }
}

class _SetupView extends StatelessWidget {
  const _SetupView({
    super.key,
    required this.level,
    required this.exam,
    required this.setId,
    required this.onLevel,
    required this.onExam,
    required this.onSet,
    required this.onStart,
  });

  final Level level;
  final bool exam;
  final String? setId;
  final ValueChanged<Level> onLevel;
  final ValueChanged<bool> onExam;
  final ValueChanged<String?> onSet;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final labelStyle = TextStyle(
      color: luma.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        LumaCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LumaIconBadge(icon: Icons.science_rounded, color: luma.accent, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.schoolPtaTitle, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      t.schoolPtaIntro,
                      style: TextStyle(color: luma.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 28,
          runSpacing: 16,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.schoolPtaLevel, style: labelStyle),
                const SizedBox(height: 8),
                LumaSegmentedTabs(
                  tabs: [t.schoolPtaHavo, t.schoolPtaVwo],
                  selectedIndex: level == Level.havo ? 0 : 1,
                  onSelect: (i) => onLevel(i == 0 ? Level.havo : Level.vwo),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.schoolPtaMode, style: labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _OptionCard(
                      icon: Icons.school_outlined,
                      title: t.schoolPtaModePractice,
                      subtitle: t.schoolPtaModePracticeHint,
                      selected: !exam,
                      onTap: () => onExam(false),
                    ),
                    _OptionCard(
                      icon: Icons.timer_outlined,
                      title: t.schoolPtaModeExam,
                      subtitle: t.schoolPtaModeExamHint,
                      selected: exam,
                      onTap: () => onExam(true),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(t.schoolPtaSet, style: labelStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SetCard(
              title: t.schoolPtaRandomSet,
              focus: t.schoolPtaRandomSetHint,
              formulas: const [],
              selected: setId == null,
              onTap: () => onSet(null),
            ),
            for (final s in setsFor(level))
              _SetCard(
                title: s.title,
                focus: s.focus,
                formulas: [for (final c in s.candidates) c.formula],
                badge: s.level == Level.vwo ? t.schoolPtaVwo : null,
                selected: setId == s.id,
                onTap: () => onSet(s.id),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: IntrinsicWidth(
            child: LumaPrimaryButton(
              label: t.schoolPtaStart,
              icon: Icons.play_arrow_rounded,
              onTap: onStart,
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return _Selectable(
      selected: selected,
      onTap: onTap,
      width: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: selected ? luma.accent : luma.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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

class _SetCard extends StatelessWidget {
  const _SetCard({
    required this.title,
    required this.focus,
    required this.formulas,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String focus;
  final List<String> formulas;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return _Selectable(
      selected: selected,
      onTap: onTap,
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: luma.accentSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: luma.accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(focus, style: TextStyle(color: luma.textMuted, fontSize: 12)),
          if (formulas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in formulas)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: luma.surfaceHover,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(color: luma.textSecondary, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Selectable extends StatelessWidget {
  const _Selectable({
    required this.selected,
    required this.onTap,
    required this.width,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : luma.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? luma.accent : luma.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
