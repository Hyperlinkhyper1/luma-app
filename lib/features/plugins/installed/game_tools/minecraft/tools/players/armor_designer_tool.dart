import 'dart:isolate';

import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/leather_dye.dart';
import '../../data/mc_dyes.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_style.dart';

enum _Piece {
  helmet('helmet'),
  chestplate('chestplate'),
  leggings('leggings'),
  boots('boots');

  const _Piece(this.id);
  final String id;
}

enum _Material {
  leather('leather', 'Leather', Color(0xFFA06540)),
  chainmail('chainmail', 'Chainmail', Color(0xFF8C8C8C)),
  copper('copper', 'Copper', Color(0xFFD27D5A)),
  iron('iron', 'Iron', Color(0xFFD8D8D8)),
  golden('golden', 'Gold', Color(0xFFF2D24B)),
  diamond('diamond', 'Diamond', Color(0xFF5BE3E6)),
  netherite('netherite', 'Netherite', Color(0xFF4B4548)),
  turtle('turtle', 'Turtle', Color(0xFF47BF4A));

  const _Material(this.id, this.label, this.color);
  final String id;
  final String label;
  final Color color;

  String itemFor(_Piece piece) =>
      this == turtle ? 'turtle_helmet' : '${id}_${piece.id}';
}

const _trimMaterials = {
  'amethyst': Color(0xFF9A5CC6),
  'copper': Color(0xFFB4684D),
  'diamond': Color(0xFF6EECD2),
  'emerald': Color(0xFF11A036),
  'gold': Color(0xFFDEB12D),
  'iron': Color(0xFFECECEC),
  'lapis': Color(0xFF416E97),
  'netherite': Color(0xFF625859),
  'quartz': Color(0xFFE3D4C4),
  'redstone': Color(0xFF971607),
  'resin': Color(0xFFFC7812),
};

const _trimPatterns = [
  'sentry', 'dune', 'coast', 'wild', 'tide', 'ward', 'silence', 'vex', 'eye',
  'snout', 'rib', 'spire', 'wayfinder', 'raiser', 'shaper', 'host', 'flow', 'bolt',
];

String _trimSource(L t, String trim) => switch (trim) {
  'sentry' => t.mcTrimSentry,
  'dune' => t.mcTrimDune,
  'coast' => t.mcTrimCoast,
  'wild' => t.mcTrimWild,
  'tide' => t.mcTrimTide,
  'ward' => t.mcTrimWard,
  'silence' => t.mcTrimSilence,
  'vex' => t.mcTrimVex,
  'eye' => t.mcTrimEye,
  'snout' => t.mcTrimSnout,
  'rib' => t.mcTrimRib,
  'spire' => t.mcTrimSpire,
  'flow' => t.mcTrimFlow,
  'bolt' => t.mcTrimBolt,
  _ => t.mcTrimTrail,
};

String _pieceLabel(L t, _Piece p) => switch (p) {
  _Piece.helmet => t.mcEnchItemHelmet,
  _Piece.chestplate => t.mcEnchItemChestplate,
  _Piece.leggings => t.mcEnchItemLeggings,
  _Piece.boots => t.mcEnchItemBoots,
};

class _Slot {
  _Slot(this.piece);
  final _Piece piece;
  bool enabled = true;
  _Material material = _Material.diamond;
  String? trim = 'sentry';
  String trimMaterial = 'gold';
}

/// Armor trims and leather dyes: preview a set, find the dye mix for a
/// colour, and get the commands and smithing steps.
/// Top-level so the isolate closure captures only [target]: one made inside
/// the State's method would share a scope that holds the State itself.
Future<McDyeMatch> _bestDyeMixInIsolate(int target) =>
    Isolate.run(() => mcBestDyeMix(target));

class ArmorDesignerTool extends StatefulWidget {
  const ArmorDesignerTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<ArmorDesignerTool> createState() => _ArmorDesignerToolState();
}

class _ArmorDesignerToolState extends State<ArmorDesignerTool> {
  final List<_Slot> _slots = [for (final p in _Piece.values) _Slot(p)];
  _Piece _editing = _Piece.chestplate;
  Color _leather = const Color(0xFF3AB3DA);
  final List<McDye> _mix = [];
  McDyeMatch? _match;
  bool _searching = false;

  _Slot get _slot => _slots[_editing.index];

  Future<void> _findMix() async {
    setState(() => _searching = true);
    final target = mcRgbInt(_leather);
    final match = await _bestDyeMixInIsolate(target);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _match = match;
    });
  }

  String _commandFor(_Slot s) {
    final item = s.material.itemFor(s.piece);
    final parts = <String>[
      if (s.material == _Material.leather) 'dyed_color=${mcRgbInt(_leather)}',
      if (s.trim != null)
        'trim={pattern:"minecraft:${s.trim}",material:"minecraft:${s.trimMaterial}"}',
    ];
    return '/give @p $item${parts.isEmpty ? '' : '[${parts.join(',')}]'}';
  }

  void _applyToAll() {
    setState(() {
      for (final s in _slots) {
        s.trim = _slot.trim;
        s.trimMaterial = _slot.trimMaterial;
        if (_slot.material != _Material.turtle || s.piece == _Piece.helmet) {
          s.material = _slot.material;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final active = _slots.where((s) => s.enabled).toList();
    final commands = active.map(_commandFor).join('\n');
    final mixed = _mix.isEmpty ? null : mcMixLeather(_mix);
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 420,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcArmorPiece,
              icon: Icons.checkroom_rounded,
              trailing: TextButton(
                onPressed: _applyToAll,
                child: Text(t.mcArmorApplyAll),
              ),
              child: McFormColumn(
                gap: 10,
                children: [
                  McChoice<_Piece>(
                    values: _Piece.values,
                    selected: _editing,
                    label: (p) => _pieceLabel(t, p),
                    onSelect: (p) => setState(() => _editing = p),
                  ),
                  McSwitch(
                    label: t.mcArmorWear,
                    value: _slot.enabled,
                    onChanged: (v) => setState(() => _slot.enabled = v),
                  ),
                  McField(
                    label: t.mcArmorMaterial,
                    child: McChoice<_Material>(
                      values: [
                        for (final m in _Material.values)
                          if (m != _Material.turtle || _editing == _Piece.helmet) m,
                      ],
                      selected: _slot.material,
                      label: (m) => m.label,
                      onSelect: (m) => setState(() => _slot.material = m),
                    ),
                  ),
                ],
              ),
            ),
            McPanel(
              title: t.mcArmorTrim,
              icon: Icons.auto_awesome_rounded,
              child: McFormColumn(
                gap: 10,
                children: [
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      ChoiceChip(
                        label: Text(t.mcArmorNone),
                        selected: _slot.trim == null,
                        onSelected: (_) => setState(() => _slot.trim = null),
                      ),
                      for (final trim in _trimPatterns)
                        ChoiceChip(
                          label: Text(mcPretty(trim)),
                          selected: _slot.trim == trim,
                          onSelected: (_) => setState(() => _slot.trim = trim),
                        ),
                    ],
                  ),
                  if (_slot.trim != null) ...[
                    Text(
                      t.mcArmorFoundIn(_trimSource(t, _slot.trim!)),
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                    McField(
                      label: t.mcArmorTrimMaterial,
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (final e in _trimMaterials.entries)
                            McSwatch(
                              color: e.value,
                              tooltip: mcPretty(e.key),
                              selected: _slot.trimMaterial == e.key,
                              onTap: () => setState(() => _slot.trimMaterial = e.key),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            McPanel(
              title: t.mcArmorLeather,
              icon: Icons.format_color_fill_rounded,
              child: McFormColumn(
                gap: 10,
                children: [
                  Row(
                    children: [
                      McSwatch(color: _leather, onTap: () {}, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: McTextField(
                          initialValue: mcHex(_leather),
                          monospace: true,
                          hint: '#RRGGBB',
                          onChanged: (v) {
                            final c = mcParseHex(v);
                            if (c != null) setState(() => _leather = c);
                          },
                        ),
                      ),
                    ],
                  ),
                  McButton(
                    label: _searching ? t.mcArmorSearching : t.mcArmorFindMix,
                    icon: Icons.search_rounded,
                    primary: false,
                    busy: _searching,
                    onTap: _findMix,
                  ),
                  if (_match != null)
                    _MatchCard(
                      match: _match!,
                      onUse: () => setState(() {
                        _leather = Color(0xFF000000 | _match!.rgb);
                        _mix
                          ..clear()
                          ..addAll(_match!.dyes);
                      }),
                    ),
                  const Divider(),
                  Text(
                    t.mcArmorMixYourself,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
                  ),
                  McDyePicker(
                    selected: null,
                    size: 22,
                    onSelect: (d) => setState(() {
                      if (_mix.length < 8) _mix.add(d);
                      _leather = Color(0xFF000000 | mcMixLeather(_mix));
                    }),
                  ),
                  if (_mix.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _mix.map((d) => d.label).join(' + '),
                            style: TextStyle(color: luma.textPrimary, fontSize: 12.5),
                          ),
                        ),
                        if (mixed != null)
                          Text(mcHex(Color(0xFF000000 | mixed)), style: mcMono(context, size: 12)),
                        McIconButton(
                          icon: Icons.backspace_outlined,
                          tooltip: t.mcArmorRemoveDye,
                          onTap: () => setState(() {
                            _mix.removeLast();
                            if (_mix.isNotEmpty) {
                              _leather = Color(0xFF000000 | mcMixLeather(_mix));
                            }
                          }),
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
                height: 360,
                child: CustomPaint(
                  painter: _ArmorPainter(
                    slots: _slots,
                    leather: _leather,
                    highlight: _editing,
                    body: luma.surfaceHover,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            if (active.any((s) => s.trim != null))
              McPanel(
                title: t.mcArmorSmithing,
                icon: Icons.handyman_rounded,
                child: McFormColumn(
                  gap: 6,
                  children: [
                    for (final s in active)
                      if (s.trim != null)
                        Text(
                          t.mcArmorSmithStep(
                            '${mcPretty(s.trim!)} Armor Trim',
                            mcPretty(s.material.itemFor(s.piece)),
                            mcPretty(s.trimMaterial),
                            _pieceLabel(t, s.piece).toLowerCase(),
                          ),
                          style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
                        ),
                    Text(
                      t.mcArmorCopyTemplate,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            McCodeBox(code: commands.isEmpty ? t.mcArmorNoPieces : commands, title: t.mcCommands),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.onUse});

  final McDyeMatch match;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final quality = match.deltaE < 2.3
        ? t.mcArmorIndistinguishable
        : match.deltaE < 6
        ? t.mcArmorVeryClose
        : match.deltaE < 12
        ? t.mcArmorClose
        : t.mcArmorNearest;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          McSwatch(color: Color(0xFF000000 | match.rgb), onTap: onUse, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  match.dyes.map((d) => d.label).join(' + '),
                  style: TextStyle(color: luma.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                Text(
                  '$quality · ΔE ${match.deltaE.toStringAsFixed(1)} · ${mcHex(Color(0xFF000000 | match.rgb))}',
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onUse, child: Text(t.mcArmorUse)),
        ],
      ),
    );
  }
}

class _ArmorPainter extends CustomPainter {
  _ArmorPainter({
    required this.slots,
    required this.leather,
    required this.highlight,
    required this.body,
  });

  final List<_Slot> slots;
  final Color leather;
  final _Piece highlight;
  final Color body;

  @override
  void paint(Canvas canvas, Size size) {
    final u = (size.height / 34).clamp(4.0, 12.0);
    final cx = size.width / 2;
    final top = (size.height - 32 * u) / 2;
    Rect r(double x, double y, double w, double h) =>
        Rect.fromLTWH(cx + x * u, top + y * u, w * u, h * u);

    final skin = Paint()..color = body;
    // Head, torso, arms, legs of a stand-in figure, in 1/16-block units.
    final head = r(-4, 0, 8, 8);
    final torso = r(-4, 8, 8, 12);
    final armL = r(-8, 8, 4, 12);
    final armR = r(4, 8, 4, 12);
    final legL = r(-4, 20, 4, 12);
    final legR = r(0, 20, 4, 12);
    for (final rect in [head, torso, armL, armR, legL, legR]) {
      canvas.drawRect(rect, skin);
    }

    Color colorOf(_Slot s) =>
        s.material == _Material.leather ? leather : s.material.color;

    void piece(_Slot s, List<Rect> rects) {
      if (!s.enabled) return;
      final c = colorOf(s);
      final fill = Paint()..color = c;
      final shade = Paint()..color = Color.lerp(c, Colors.black, 0.25)!;
      for (final rect in rects) {
        canvas.drawRect(rect, fill);
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.bottom - u, rect.width, u),
          shade,
        );
      }
      if (s.trim != null) {
        final trim = Paint()..color = _trimMaterials[s.trimMaterial]!;
        final seed = s.trim!.codeUnits.fold(0, (a, b) => a * 31 + b);
        for (final rect in rects) {
          final cols = (rect.width / u).round();
          final rows = (rect.height / u).round();
          for (var y = 0; y < rows; y++) {
            for (var x = 0; x < cols; x++) {
              final v = (x * 7 + y * 13 + seed) % 11;
              final edge = y == 0 || x == 0 || x == cols - 1;
              if ((edge && v < 4) || v == 0) {
                canvas.drawRect(
                  Rect.fromLTWH(rect.left + x * u, rect.top + y * u, u, u),
                  trim,
                );
              }
            }
          }
        }
      }
      if (s.piece == highlight) {
        for (final rect in rects) {
          canvas.drawRect(
            rect.inflate(1.5),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }

    piece(slots[_Piece.leggings.index], [r(-4, 19, 8, 3), r(-4, 22, 4, 7), r(0, 22, 4, 7)]);
    piece(slots[_Piece.boots.index], [r(-4.4, 28, 4.4, 4.4), r(0, 28, 4.4, 4.4)]);
    piece(slots[_Piece.chestplate.index], [r(-4.5, 7.6, 9, 12), r(-8.5, 7.6, 4.5, 6), r(4, 7.6, 4.5, 6)]);
    piece(slots[_Piece.helmet.index], [r(-4.6, -0.6, 9.2, 5), r(-4.6, 4.4, 1.6, 3.5), r(3, 4.4, 1.6, 3.5)]);
  }

  @override
  bool shouldRepaint(_ArmorPainter old) => true;
}
