import 'package:flutter/material.dart';

import '../../../../../../app/widgets.dart';
import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../theme/luma_theme.dart';
import '../../logic/pta/pta_chemistry.dart';
import '../../logic/pta/pta_lab.dart';
import '../../logic/pta/pta_scenarios.dart';
import 'pta_binas_sheet.dart';
import 'pta_tube.dart';

const kExamMinutes = 120;

/// The bench: the jar and its four candidates, four test tubes, the
/// reagent shelf and the lab journal.
class PtaLabView extends StatefulWidget {
  const PtaLabView({
    super.key,
    required this.lab,
    required this.set,
    required this.jarLabel,
    required this.examMinutes,
    required this.jars,
    required this.onWorksheet,
    required this.onHandIn,
    required this.onQuit,
  });

  final PtaLab lab;
  final PtaSet set;
  final String jarLabel;
  final int? examMinutes;
  final Widget jars;
  final VoidCallback onWorksheet;
  final VoidCallback onHandIn;
  final VoidCallback onQuit;

  bool get exam => examMinutes != null;

  @override
  State<PtaLabView> createState() => _PtaLabViewState();
}

class _PtaLabViewState extends State<PtaLabView> {
  int _selected = 0;
  final _versions = <int, int>{};
  int _flameVersion = 0;

  PtaLab get lab => widget.lab;
  bool get _timeUp => widget.examMinutes == 0;

  void _act(LabEntry Function() action, {int? tube, bool flame = false}) {
    if (_timeUp) return;
    setState(() {
      action();
      if (tube != null) _versions[tube] = (_versions[tube] ?? 0) + 1;
      if (flame) _flameVersion++;
    });
  }

  Future<void> _confirmQuit() async {
    final t = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(t.schoolPtaQuitConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.schoolPtaQuit),
          ),
        ],
      ),
    );
    if (mounted && ok == true) widget.onQuit();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final top = _TopBar(
          title: widget.exam ? L.of(context).schoolPtaTitle : widget.set.title,
          examMinutes: widget.examMinutes,
          minutes: lab.minutes,
          onQuit: _confirmQuit,
          onWorksheet: widget.onWorksheet,
          onHandIn: widget.onHandIn,
          jars: widget.jars,
        );
        final jar = _JarPanel(
          lab: lab,
          jarLabel: widget.jarLabel,
          candidates: widget.set.candidates,
          exam: widget.exam,
          redoxOnly: !widget.exam && (widget.set.bookletNumber ?? 5) <= 4,
          flameVersion: _flameVersion,
          enabled: !_timeUp,
          onInspect: () => _act(lab.inspect),
          onFlame: () => _act(lab.flameTest, flame: true),
        );
        final bench = _BenchPanel(
          lab: lab,
          selected: _selected,
          versions: _versions,
          timeUp: _timeUp,
          onSelect: (i) => setState(() => _selected = i),
          act: (action) => _act(action, tube: _selected),
        );
        final log = _LogPanel(lab: lab, showNotes: !widget.exam);

        if (box.maxWidth >= 1180) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                top,
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 270,
                        child: SingleChildScrollView(child: jar),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: SingleChildScrollView(child: bench)),
                      const SizedBox(width: 14),
                      SizedBox(width: 380, child: log),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        if (box.maxWidth >= 820) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                top,
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [jar, const SizedBox(height: 14), bench],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      SizedBox(width: 340, child: log),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              top,
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    jar,
                    const SizedBox(height: 12),
                    bench,
                    const SizedBox(height: 12),
                    SizedBox(height: 520, child: log),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.examMinutes,
    required this.minutes,
    required this.onQuit,
    required this.onWorksheet,
    required this.onHandIn,
    required this.jars,
  });

  final String title;
  final int? examMinutes;
  final int minutes;
  final VoidCallback onQuit;
  final VoidCallback onWorksheet;
  final VoidCallback onHandIn;
  final Widget jars;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final remaining = examMinutes;
    final exam = remaining != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IntrinsicWidth(
              child: LumaGhostButton(
                label: t.schoolPtaQuit,
                icon: Icons.arrow_back_rounded,
                onTap: onQuit,
              ),
            ),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            _Pill(
              text: exam ? t.schoolPtaModeExam : t.schoolPtaModePractice,
              color: exam ? luma.warning : luma.accent,
            ),
            _Pill(
              icon: Icons.timer_outlined,
              text: exam
                  ? '${t.schoolPtaTimeLeft} · ${t.schoolPtaMinutes(remaining, kExamMinutes)}'
                  : "$minutes'",
              color: exam && remaining <= 15 ? luma.danger : luma.textSecondary,
            ),
            IntrinsicWidth(
              child: LumaGhostButton(
                label: t.schoolPtaWorksheet,
                icon: Icons.edit_note_rounded,
                onTap: onWorksheet,
              ),
            ),
            IntrinsicWidth(
              child: LumaGhostButton(
                label: t.schoolPtaBinas,
                icon: Icons.menu_book_rounded,
                onTap: () => showPtaBinas(context),
              ),
            ),
            IntrinsicWidth(
              child: LumaPrimaryButton(
                label: t.schoolPtaHandIn,
                icon: Icons.task_alt_rounded,
                onTap: onHandIn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        jars,
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

class _JarPanel extends StatelessWidget {
  const _JarPanel({
    required this.lab,
    required this.jarLabel,
    required this.candidates,
    required this.exam,
    required this.redoxOnly,
    required this.flameVersion,
    required this.enabled,
    required this.onInspect,
    required this.onFlame,
  });

  final PtaLab lab;
  final String jarLabel;
  final List<Substance> candidates;
  final bool exam;
  final bool redoxOnly;
  final int flameVersion;
  final bool enabled;
  final VoidCallback onInspect;
  final VoidCallback onFlame;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t.schoolPtaJar} $jarLabel',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PtaJar(
                label: jarLabel,
                substance: lab.unknown,
                glass: luma.textMuted,
              ),
              const SizedBox(width: 18),
              PtaFlame(color: lab.lastFlame, version: flameVersion),
            ],
          ),
          if (redoxOnly) ...[
            const SizedBox(height: 12),
            Text(t.schoolPtaRedoxOnly),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                icon: Icons.visibility_outlined,
                label: t.schoolPtaInspect,
                onTap: enabled ? onInspect : null,
              ),
              _ActionButton(
                icon: Icons.local_fire_department_outlined,
                label: t.schoolPtaFlame,
                onTap: enabled ? onFlame : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            t.schoolPtaCandidates,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < candidates.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      String.fromCharCode(65 + i),
                      style: TextStyle(
                        color: luma.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          candidates[i].name,
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!exam)
                          Text(
                            candidates[i].notation,
                            style: TextStyle(color: luma.textSecondary),
                          ),
                      ],
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

class _BenchPanel extends StatelessWidget {
  const _BenchPanel({
    required this.lab,
    required this.selected,
    required this.versions,
    required this.timeUp,
    required this.onSelect,
    required this.act,
  });

  final PtaLab lab;
  final int selected;
  final Map<int, int> versions;
  final bool timeUp;
  final ValueChanged<int> onSelect;
  final void Function(LabEntry Function() action) act;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final enabled = !timeUp;
    VoidCallback? on(LabEntry Function() f) => enabled ? () => act(f) : null;
    final i = selected;
    final sectionStyle = TextStyle(
      color: luma.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (timeUp)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: luma.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                t.schoolPtaTimeUp,
                style: TextStyle(
                  color: luma.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: luma.surfaceHover.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var n = 0; n < lab.tubes.length; n++)
                  PtaTubeView(
                    tube: lab.tubes[n],
                    version: versions[n] ?? 0,
                    selected: n == selected,
                    label: t.schoolPtaTube(n + 1),
                    onTap: () => onSelect(n),
                    glass: luma.textMuted,
                    accent: luma.accent,
                    labelStyle: TextStyle(
                      color: n == selected ? luma.accent : luma.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(t.schoolPtaTube(i + 1), style: sectionStyle),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                icon: Icons.science_outlined,
                label: t.schoolPtaSample,
                onTap: on(() => lab.addSample(i)),
              ),
              _ActionButton(
                icon: Icons.water_drop_outlined,
                label: t.schoolPtaWater,
                onTap: on(() => lab.addWater(i)),
              ),
              _ActionButton(
                icon: Icons.local_fire_department_outlined,
                label: t.schoolPtaHeat,
                onTap: on(() => lab.heat(i)),
              ),
              _ActionButton(
                icon: Icons.palette_outlined,
                label: t.schoolPtaPaper,
                onTap: on(() => lab.paper(i)),
              ),
              PopupMenuButton<GasTest>(
                enabled: enabled,
                tooltip: t.schoolPtaGasTests,
                onSelected: (g) => act(() => lab.gasTest(i, g)),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: GasTest.iodinePaper,
                    child: Text(t.schoolPtaIodinePaper),
                  ),
                  PopupMenuItem(
                    value: GasTest.limewater,
                    child: Text(t.schoolPtaLimewater),
                  ),
                  PopupMenuItem(
                    value: GasTest.litmus,
                    child: Text(t.schoolPtaLitmus),
                  ),
                  PopupMenuItem(
                    value: GasTest.glowingSplint,
                    child: Text(t.schoolPtaGlowingSplint),
                  ),
                  PopupMenuItem(
                    value: GasTest.burningSplint,
                    child: Text(t.schoolPtaBurningSplint),
                  ),
                ],
                child: _ActionButton(
                  icon: Icons.bubble_chart_outlined,
                  label: t.schoolPtaGasTests,
                  trailing: Icons.arrow_drop_down_rounded,
                  onTap: null,
                  forceEnabledLook: enabled,
                ),
              ),
              _ActionButton(
                icon: Icons.cleaning_services_outlined,
                label: t.schoolPtaRinse,
                onTap: on(() => lab.rinse(i)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(t.schoolPtaReagents, style: sectionStyle),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in reagents.where(
                (r) => r.kind != ReagentKind.water,
              ))
                r.hasDose
                    ? PopupMenuButton<Dose>(
                        enabled: enabled,
                        tooltip: r.label,
                        onSelected: (d) => act(() => lab.addReagent(i, r, d)),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: Dose.drops,
                            child: Text(t.schoolPtaDrops),
                          ),
                          PopupMenuItem(
                            value: Dose.excess,
                            child: Text(t.schoolPtaExcess),
                          ),
                        ],
                        child: _Bottle(reagent: r, enabled: enabled),
                      )
                    : _Bottle(
                        reagent: r,
                        enabled: enabled,
                        onTap: () => act(() => lab.addReagent(i, r)),
                      ),
            ],
          ),
          const SizedBox(height: 16),
          Text(t.schoolPtaMetals, style: sectionStyle),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in const [Metal.mg, Metal.zn, Metal.cu, Metal.fe])
                _ShelfChip(
                  color: Color(m.argb),
                  title: m.name,
                  subtitle: m.symbol,
                  enabled: enabled,
                  onTap: () => act(() => lab.addMetal(i, m)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.forceEnabledLook = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool forceEnabledLook;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final enabled = onTap != null || forceEnabledLook;
    final fg = enabled ? luma.textPrimary : luma.textMuted;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: enabled ? luma.accent : luma.textMuted),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null) Icon(trailing, size: 18, color: fg),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _Bottle extends StatelessWidget {
  const _Bottle({required this.reagent, required this.enabled, this.onTap});
  final Reagent reagent;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _ShelfChip(
    color: reagent.color,
    title: reagent.name,
    subtitle: reagent.label,
    enabled: enabled,
    onTap: onTap,
  );
}

class _ShelfChip extends StatelessWidget {
  const _ShelfChip({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onTap,
  });

  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final body = Container(
      width: 196,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          CustomPaint(
            size: const Size(16, 24),
            painter: _BottlePainter(color, luma.textMuted),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? luma.textPrimary : luma.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? onTap : null,
        child: body,
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  _BottlePainter(this.liquid, this.glass);
  final Color liquid;
  final Color glass;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromLTRBR(
      1,
      7,
      size.width - 1,
      size.height,
      const Radius.circular(4),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        1,
        size.height * 0.45,
        size.width - 1,
        size.height,
        const Radius.circular(4),
      ),
      Paint()..color = liquid.a < 0.3 ? glass.withValues(alpha: 0.18) : liquid,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = glass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawRect(
      Rect.fromLTRB(size.width * 0.3, 0, size.width * 0.7, 7),
      Paint()..color = glass,
    );
  }

  @override
  bool shouldRepaint(_BottlePainter old) =>
      old.liquid != liquid || old.glass != glass;
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.lab, required this.showNotes});
  final PtaLab lab;
  final bool showNotes;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final entries = lab.log.reversed.toList();
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, color: luma.accent),
              const SizedBox(width: 8),
              Text(
                t.schoolPtaLog,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      t.schoolPtaLogEmpty,
                      style: TextStyle(color: luma.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: luma.border, height: 18),
                    itemBuilder: (context, n) => _LogEntryView(
                      entry: entries[n],
                      showNotes: showNotes,
                      fresh: n == 0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogEntryView extends StatelessWidget {
  const _LogEntryView({
    required this.entry,
    required this.showNotes,
    required this.fresh,
  });

  final LabEntry entry;
  final bool showNotes;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: fresh ? luma.accent : luma.accentSubtle,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "${entry.minute}'",
                style: TextStyle(
                  color: fresh ? luma.onAccent : luma.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.action,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        for (final o in entry.observations)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 7),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: luma.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (entry.paper != null)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 6, top: 1),
                    decoration: BoxDecoration(
                      color: Color(entry.paper!.argb),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                if (entry.flame != null)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 6, top: 1),
                    decoration: BoxDecoration(
                      color: entry.flame,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    o,
                    style: TextStyle(color: luma.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        if (showNotes && (entry.notes.isNotEmpty || entry.equations.isNotEmpty))
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: luma.accentSubtle,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in entry.notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      n,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                for (final e in entry.equations)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      e,
                      style: TextStyle(
                        color: luma.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
