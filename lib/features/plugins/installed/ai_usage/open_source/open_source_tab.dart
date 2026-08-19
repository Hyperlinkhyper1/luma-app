import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../leaderboard/ai_catalog_scope.dart';
import '../leaderboard/ai_leaderboard_format.dart';
import '../leaderboard/ai_model.dart';
import 'vram_estimate.dart';

/// The plugin's **Open Source** section: pick an open-weight model and see
/// what it takes to run it yourself, and which hardware can.
///
/// Everything here is computed on the device from the catalogue's parameter
/// counts — no request is made and nothing is sent anywhere.
class OpenSourceTab extends StatefulWidget {
  const OpenSourceTab({super.key});

  @override
  State<OpenSourceTab> createState() => _OpenSourceTabState();
}

class _OpenSourceTabState extends State<OpenSourceTab> {
  AiModel? _model;
  Quantization _quantization = Quantization.q4;
  int _context = 8192;
  bool _kv8bit = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiCatalogScope.of(context).load();
  }

  /// Only models whose weights are downloadable *and* whose parameter count is
  /// known — without the count there is nothing to size, and guessing one
  /// would be worse than leaving the model out.
  List<AiModel> _runnable(List<AiModel> models) {
    final list = [
      for (final m in models)
        if (m.openWeights && (m.parametersB ?? 0) > 0) m,
    ]..sort((a, b) => b.parametersB!.compareTo(a.parametersB!));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final repo = AiCatalogScope.of(context);
    final luma = context.luma;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (repo.loading) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }

        final models = _runnable(repo.catalog.models);
        if (models.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: LumaEmptyState(
              icon: Icons.memory_outlined,
              title: 'No open-weight models yet',
              subtitle: 'This calculator sizes models whose weights you can '
                  'download. None in the current catalogue have a known '
                  'parameter count — refresh the leaderboard and try again.',
            ),
          );
        }

        final model = _model ?? models.first;
        final estimate = estimateVram(
          parametersB: model.parametersB!,
          quantization: _quantization,
          contextTokens: _context,
          kvCacheBits: _kv8bit ? 8 : 16,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _Controls(
              models: models,
              model: model,
              onModel: (m) => setState(() => _model = m),
              quantization: _quantization,
              onQuantization: (q) => setState(() => _quantization = q),
              context: _context,
              onContext: (c) => setState(() => _context = c),
              kv8bit: _kv8bit,
              onKv8bit: (v) => setState(() => _kv8bit = v),
            ),
            const SizedBox(height: 16),
            _EstimateCard(model: model, estimate: estimate),
            const SizedBox(height: 16),
            Text(
              'WHAT CAN RUN IT',
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            LumaCard(
              child: Column(
                children: [
                  for (final hardware in kHardwareProfiles)
                    _HardwareRow(
                      hardware: hardware,
                      verdict: fitIn(estimate, hardware.vramGb),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Weight memory is exact arithmetic. The context cost is '
              'estimated from the parameter count — the catalogue does not '
              'carry each model’s layer count or attention shape, so a model '
              'with an unusual design will differ. Leave headroom.',
              style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.5),
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.models,
    required this.model,
    required this.onModel,
    required this.quantization,
    required this.onQuantization,
    required this.context,
    required this.onContext,
    required this.kv8bit,
    required this.onKv8bit,
  });

  final List<AiModel> models;
  final AiModel model;
  final ValueChanged<AiModel> onModel;
  final Quantization quantization;
  final ValueChanged<Quantization> onQuantization;
  final int context;
  final ValueChanged<int> onContext;
  final bool kv8bit;
  final ValueChanged<bool> onKv8bit;

  @override
  Widget build(BuildContext buildContext) {
    final luma = buildContext.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(
            label: 'Model',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AiModel>(
                value: model,
                isExpanded: true,
                dropdownColor: luma.surface,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
                items: [
                  for (final m in models)
                    DropdownMenuItem(
                      value: m,
                      child: Text(
                        '${m.name} · ${m.parametersB!.toStringAsFixed(
                          m.parametersB! >= 100 ? 0 : 1,
                        )}B',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (m) {
                  if (m != null) onModel(m);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'Quantization',
            help: quantization.blurb,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in Quantization.values)
                  _Chip(
                    label: q.label,
                    selected: q == quantization,
                    onTap: () => onQuantization(q),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'Context',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in kContextPresets)
                  _Chip(
                    label: formatTokens(c) ?? '$c',
                    selected: c == context,
                    onTap: () => onContext(c),
                  ),
                _Chip(
                  label: '8-bit KV',
                  selected: kv8bit,
                  onTap: () => onKv8bit(!kv8bit),
                  tooltip: 'Store the context cache at 8 bits instead of 16 — '
                      'roughly halves what the context costs.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.help});

  final String label;
  final String? help;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: luma.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (help != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  help!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final chip = Material(
      color: selected ? luma.accentSubtle : luma.background,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: selected ? luma.accent : luma.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? luma.textPrimary : luma.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.model, required this.estimate});

  final AiModel model;
  final VramEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                estimate.totalGb.toStringAsFixed(1),
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('GB of memory',
                    style: TextStyle(color: luma.textSecondary, fontSize: 14)),
              ),
              const Spacer(),
              if (model.licenseName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_open_rounded,
                          size: 14, color: luma.success),
                      const SizedBox(width: 5),
                      Text(model.licenseName!,
                          style: TextStyle(
                              color: luma.textMuted, fontSize: 11.5)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Breakdown(estimate: estimate),
        ],
      ),
    );
  }
}

/// Where the memory goes, as a stacked bar plus a legend. Each part is
/// labelled with its own figure — the bar shows proportion, the text carries
/// the value.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.estimate});

  final VramEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final parts = <(String, double, Color)>[
      ('Weights', estimate.weightsGb, luma.accent),
      ('Context cache', estimate.kvCacheGb, const Color(0xFF6EE7B7)),
      ('Runtime', estimate.overheadGb, const Color(0xFFFDE68A)),
    ];
    final total = estimate.totalGb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final (_, value, color) in parts)
                  Expanded(
                    flex: (value / total * 1000).round().clamp(1, 1000),
                    child: ColoredBox(color: color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            for (final (label, value, color) in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text('$label ',
                      style: TextStyle(
                          color: luma.textSecondary, fontSize: 12.5)),
                  Text(
                    '${value.toStringAsFixed(1)} GB',
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _HardwareRow extends StatelessWidget {
  const _HardwareRow({required this.hardware, required this.verdict});

  final HardwareProfile hardware;
  final FitVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final (label, color, icon) = switch (verdict) {
      FitVerdict.comfortable => ('Runs well', luma.success, Icons.check_circle_rounded),
      FitVerdict.tight => ('Tight fit', const Color(0xFFFDE68A), Icons.warning_amber_rounded),
      FitVerdict.spills =>
        ('Spills to RAM', const Color(0xFFFCA5A5), Icons.swap_vert_rounded),
      FitVerdict.wontRun => ('Won’t run', luma.textMuted, Icons.block_rounded),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              hardware.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textPrimary, fontSize: 13),
            ),
          ),
          SizedBox(
            width: 78,
            child: Text(
              '${hardware.vramGb.toStringAsFixed(hardware.vramGb % 1 == 0 ? 0 : 1)} GB',
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ),
          // Verdict is an icon *and* words, never colour on its own.
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12.5)),
          const Spacer(),
          if (hardware.unified)
            Tooltip(
              message: 'Shared CPU/GPU memory — this is the share a model can '
                  'actually claim, not the machine’s total.',
              child: Text('unified',
                  style: TextStyle(color: luma.textMuted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
