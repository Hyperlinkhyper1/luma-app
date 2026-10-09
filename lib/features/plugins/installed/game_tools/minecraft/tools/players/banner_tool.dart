import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/banner_patterns.dart';
import '../../data/mc_dyes.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

/// Banner and shield designer: stack patterns, see it drawn, and get the loom
/// steps and a `/give` command. With [shield] the same design goes on a
/// shield.
class BannerTool extends StatefulWidget {
  const BannerTool({super.key, required this.host, this.shield = false});

  final McToolHost host;
  final bool shield;

  @override
  State<BannerTool> createState() => _BannerToolState();
}

class _BannerToolState extends State<BannerTool> {
  McDye _base = McDye.white;
  final List<McBannerLayer> _layers = [
    McBannerLayer('stripe_bottom', McDye.blue),
    McBannerLayer('circle', McDye.red),
  ];
  McDye _brush = McDye.black;
  String _target = '@p';

  static const _survivalLimit = 6;
  static const _maxLayers = 16;

  void _add(McBannerPattern p) {
    if (_layers.length >= _maxLayers) return;
    setState(() => _layers.add(McBannerLayer(p.id, _brush)));
  }

  void _randomize() {
    final r = math.Random();
    setState(() {
      _base = McDye.values[r.nextInt(16)];
      _layers
        ..clear()
        ..addAll([
          for (var i = 0; i < 3 + r.nextInt(3); i++)
            McBannerLayer(
              kMcBannerPatterns[r.nextInt(kMcBannerPatterns.length)].id,
              McDye.values[r.nextInt(16)],
            ),
        ]);
    });
  }

  String get _command {
    final patterns = _layers
        .map((l) => '{pattern:"minecraft:${l.pattern}",color:"${l.color.id}"}')
        .join(',');
    if (widget.shield) {
      return '/give $_target shield[base_color="${_base.id}"'
          '${_layers.isEmpty ? '' : ',banner_patterns=[$patterns]'}] 1';
    }
    return '/give $_target ${_base.id}_banner'
        '${_layers.isEmpty ? '' : '[banner_patterns=[$patterns]]'} 1';
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final overLimit = _layers.length > _survivalLimit;
    return widget.host.frame(
      context,
      actions: [
        McButton(
          label: t.mcBannerRandomize,
          icon: Icons.casino_rounded,
          primary: false,
          onTap: _randomize,
        ),
      ],
      child: McSplit(
        controlsWidth: 420,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcBannerBase,
              icon: Icons.format_color_fill_rounded,
              child: McDyePicker(
                selected: _base,
                onSelect: (d) => setState(() => _base = d),
              ),
            ),
            McPanel(
              title: t.mcBannerAdd,
              icon: Icons.add_box_rounded,
              trailing: Text(
                '${_layers.length}/$_maxLayers',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              child: McFormColumn(
                gap: 10,
                children: [
                  Row(
                    children: [
                      Text(t.mcBannerDye, style: TextStyle(color: luma.textSecondary, fontSize: 12.5)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: McDyePicker(
                          selected: _brush,
                          size: 20,
                          onSelect: (d) => setState(() => _brush = d),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in kMcBannerPatterns)
                        _PatternThumb(
                          pattern: p,
                          base: _base,
                          dye: _brush,
                          onTap: () => _add(p),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        result: McFormColumn(
          children: [
            McPanel(
              child: SizedBox(
                height: 330,
                child: CustomPaint(
                  painter: McBannerPainter(
                    base: _base,
                    layers: _layers,
                    shield: widget.shield,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            if (overLimit)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: luma.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t.mcBannerLoomLimit(_survivalLimit),
                  style: TextStyle(color: luma.textPrimary, fontSize: 12.5),
                ),
              ),
            McPanel(
              title: t.mcBannerLayers,
              icon: Icons.layers_rounded,
              child: _layers.isEmpty
                  ? Text(
                      t.mcBannerEmpty,
                      style: TextStyle(color: luma.textMuted, fontSize: 12.5),
                    )
                  : ReorderableListView(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorderItem: (from, to) => setState(
                        () => _layers.insert(to, _layers.removeAt(from)),
                      ),
                      children: [
                        for (var i = 0; i < _layers.length; i++)
                          _LayerRow(
                            key: ObjectKey(_layers[i]),
                            index: i,
                            layer: _layers[i],
                            overLimit: i >= _survivalLimit,
                            onColor: (d) => setState(() => _layers[i].color = d),
                            onRemove: () => setState(() => _layers.removeAt(i)),
                          ),
                      ],
                    ),
            ),
            McPanel(
              title: t.mcBannerSteps,
              icon: Icons.format_list_numbered_rounded,
              child: McFormColumn(
                gap: 6,
                children: [
                  _StepText(
                    0,
                    '${t.mcBannerCraft('${_base.label} Banner', '${_base.label} Wool')}'
                    '${widget.shield ? ' ${t.mcBannerShieldStep}' : ''}',
                  ),
                  for (var i = 0; i < _layers.length; i++)
                    _StepText(
                      i + 1,
                      t.mcBannerLoomStep(
                        '${_layers[i].color.label} Dye'
                        '${mcBannerPattern(_layers[i].pattern).item == null ? '' : ' + ${mcPretty(mcBannerPattern(_layers[i].pattern).item!)}'}',
                        mcBannerPattern(_layers[i].pattern).name,
                      ),
                      muted: i >= _survivalLimit,
                    ),
                ],
              ),
            ),
            McField(
              label: t.mcGiveTo,
              child: McTextField(
                initialValue: _target,
                monospace: true,
                onChanged: (v) => setState(() => _target = v.trim().isEmpty ? '@p' : v.trim()),
              ),
            ),
            McCodeBox(code: _command, title: t.mcCommand),
          ],
        ),
      ),
    );
  }
}

class _PatternThumb extends StatelessWidget {
  const _PatternThumb({
    required this.pattern,
    required this.base,
    required this.dye,
    required this.onTap,
  });

  final McBannerPattern pattern;
  final McDye base;
  final McDye dye;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final contrast = base == dye
        ? (base == McDye.white ? McDye.black : McDye.white)
        : base;
    return Tooltip(
      message: pattern.item == null
          ? pattern.name
          : L.of(context).mcBannerNeeds(pattern.name, mcPretty(pattern.item!)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 34,
          height: 58,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: luma.surfaceHover,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: luma.border),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: McBannerPainter(
                    base: contrast,
                    layers: [McBannerLayer(pattern.id, dye)],
                  ),
                ),
              ),
              if (pattern.item != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Icon(Icons.star_rounded, size: 10, color: McHue.amber.color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    super.key,
    required this.index,
    required this.layer,
    required this.overLimit,
    required this.onColor,
    required this.onRemove,
  });

  final int index;
  final McBannerLayer layer;
  final bool overLimit;
  final ValueChanged<McDye> onColor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_indicator_rounded, size: 18, color: luma.textMuted),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 18,
            height: 32,
            child: CustomPaint(
              painter: McBannerPainter(
                base: layer.color == McDye.white ? McDye.gray : McDye.white,
                layers: [layer],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${index + 1}. ${mcBannerPattern(layer.pattern).name}',
              style: TextStyle(
                color: overLimit ? luma.textMuted : luma.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          PopupMenuButton<McDye>(
            tooltip: L.of(context).mcBannerChangeColour,
            onSelected: onColor,
            itemBuilder: (_) => [
              for (final d in McDye.values)
                PopupMenuItem(
                  value: d,
                  child: Row(
                    children: [
                      Container(width: 14, height: 14, color: d.color),
                      const SizedBox(width: 8),
                      Text(d.label),
                    ],
                  ),
                ),
            ],
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: layer.color.color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: luma.border),
              ),
            ),
          ),
          McIconButton(
            icon: Icons.close_rounded,
            tooltip: L.of(context).mcBannerRemoveLayer,
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

class _StepText extends StatelessWidget {
  const _StepText(this.index, this.text, {this.muted = false});

  final int index;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            index == 0 ? '•' : '$index.',
            style: TextStyle(color: luma.accent, fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: muted ? luma.textMuted : luma.textSecondary,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
