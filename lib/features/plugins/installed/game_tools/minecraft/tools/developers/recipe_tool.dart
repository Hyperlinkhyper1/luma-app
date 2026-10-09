import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../../../l10n/app_localizations.dart';
import '../../../../../../../theme/luma_theme.dart';
import '../../data/mc_registries_data.dart';
import '../../mc_tool_host.dart';
import '../../ui/mc_files.dart';
import '../../ui/mc_style.dart';

enum _Kind {
  shaped('crafting_shaped'),
  shapeless('crafting_shapeless'),
  smelting('smelting'),
  blasting('blasting'),
  smoking('smoking'),
  campfire('campfire_cooking'),
  stonecutting('stonecutting'),
  smithing('smithing_transform');

  const _Kind(this.type);
  final String type;

  String label(L t) => switch (this) {
    shaped => t.mcRecShaped,
    shapeless => t.mcRecShapeless,
    smelting => t.mcRecFurnace,
    blasting => t.mcRecBlast,
    smoking => t.mcRecSmoker,
    campfire => t.mcRecCampfire,
    stonecutting => t.mcRecStonecutter,
    smithing => t.mcRecSmithing,
  };

  bool get cooking => this == smelting || this == blasting || this == smoking || this == campfire;

  int get defaultTime => switch (this) {
    smelting => 200,
    campfire => 600,
    _ => 100,
  };
}

String _id(String v) {
  final t = v.trim();
  if (t.isEmpty) return '';
  if (t.startsWith('#')) return t.contains(':') ? t : '#minecraft:${t.substring(1)}';
  return t.contains(':') ? t : 'minecraft:$t';
}

/// Datapack recipes for every station, written in the 26.x recipe format.
class RecipeTool extends StatefulWidget {
  const RecipeTool({super.key, required this.host});

  final McToolHost host;

  @override
  State<RecipeTool> createState() => _RecipeToolState();
}

class _RecipeToolState extends State<RecipeTool> {
  _Kind _kind = _Kind.shaped;
  final List<String> _grid = List.filled(9, '');
  String _brush = 'diamond';
  String _result = 'diamond_block';
  int _count = 1;
  String _group = '';
  String _category = 'misc';
  String _input = 'iron_ore';
  double _xp = 0.7;
  int _time = 200;
  String _template = 'netherite_upgrade_smithing_template';
  String _base = 'diamond_sword';
  String _addition = 'netherite_ingot';
  String _name = 'my_recipe';

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 9; i++) {
      _grid[i] = 'diamond';
    }
  }

  List<String> get _categories => _kind.cooking
      ? const ['food', 'blocks', 'misc']
      : const ['building', 'redstone', 'equipment', 'misc'];

  Map<String, Object> get _recipe {
    final result = <String, Object>{'id': _id(_result), if (_count > 1) 'count': _count};
    final base = <String, Object>{'type': 'minecraft:${_kind.type}'};
    if (_categories.contains(_category) && _kind != _Kind.stonecutting && _kind != _Kind.smithing) {
      base['category'] = _category;
    }
    if (_group.trim().isNotEmpty) base['group'] = _group.trim();
    switch (_kind) {
      case _Kind.shaped:
        // Trim empty rows and columns so a 2×2 recipe works anywhere in the
        // grid, the way vanilla patterns are written.
        var rows = [0, 1, 2].where((r) => [0, 1, 2].any((c) => _grid[r * 3 + c].isNotEmpty)).toList();
        var cols = [0, 1, 2].where((c) => [0, 1, 2].any((r) => _grid[r * 3 + c].isNotEmpty)).toList();
        if (rows.isEmpty) rows = [0];
        if (cols.isEmpty) cols = [0];
        rows = [for (var r = rows.first; r <= rows.last; r++) r];
        cols = [for (var c = cols.first; c <= cols.last; c++) c];
        final keys = <String, String>{};
        const letters = '#XABCDEFGH';
        final pattern = [
          for (final r in rows)
            cols.map((c) {
              final item = _grid[r * 3 + c];
              if (item.isEmpty) return ' ';
              return keys.putIfAbsent(_id(item), () => letters[keys.length]);
            }).join(),
        ];
        return {
          ...base,
          'key': {for (final e in keys.entries) e.value: e.key},
          'pattern': pattern,
          'result': result,
        };
      case _Kind.shapeless:
        return {
          ...base,
          'ingredients': [for (final g in _grid) if (g.isNotEmpty) _id(g)],
          'result': result,
        };
      case _Kind.smelting:
      case _Kind.blasting:
      case _Kind.smoking:
      case _Kind.campfire:
        return {
          ...base,
          'cookingtime': _time,
          'experience': double.parse(_xp.toStringAsFixed(2)),
          'ingredient': _id(_input),
          'result': {'id': _id(_result)},
        };
      case _Kind.stonecutting:
        return {...base, 'ingredient': _id(_input), 'result': result};
      case _Kind.smithing:
        return {
          ...base,
          'addition': _id(_addition),
          'base': _id(_base),
          'result': {'id': _id(_result)},
          'template': _id(_template),
        };
    }
  }

  String get _path => 'data/luma/recipe/${mcSlug(_name, fallback: 'recipe')}.json';

  Widget _slot(int i) {
    final t = L.of(context);
    final item = _grid[i];
    return GestureDetector(
      onTap: () => setState(() => _grid[i] = _grid[i] == _brush ? '' : _brush),
      onSecondaryTap: () => setState(() => _grid[i] = ''),
      onLongPress: () => setState(() => _grid[i] = ''),
      child: Tooltip(
        message: item.isEmpty ? t.mcRecEmptySlot(mcPretty(_brush)) : t.mcRecFilledSlot(mcPretty(item)),
        child: Container(
          width: 74,
          height: 74,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF8B8B8B),
            border: Border.all(color: const Color(0xFF373737), width: 2),
          ),
          child: item.isEmpty
              ? null
              : Text(
                  mcPretty(item),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, shadows: [Shadow(color: Colors.black54, offset: Offset(1, 1))]),
                ),
        ),
      ),
    );
  }

  Widget _idField(String label, String value, ValueChanged<String> set, {bool tags = false}) => McField(
    label: label,
    child: McIdField(
      options: kMcItems,
      value: value,
      hint: tags ? L.of(context).mcRecIdOrTag : L.of(context).mcRecId,
      onChanged: (v) => setState(() => set(v.trim())),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final json = const JsonEncoder.withIndent('  ').convert(_recipe);
    final grid = _kind == _Kind.shaped || _kind == _Kind.shapeless;
    return widget.host.frame(
      context,
      child: McSplit(
        controlsWidth: 440,
        controls: McFormColumn(
          children: [
            McPanel(
              title: t.mcRecStation,
              icon: Icons.handyman_rounded,
              child: McChoice<_Kind>(
                values: _Kind.values,
                selected: _kind,
                label: (k) => k.label(t),
                onSelect: (k) => setState(() {
                  _kind = k;
                  _time = k.defaultTime;
                  if (!_categories.contains(_category)) _category = 'misc';
                }),
              ),
            ),
            McPanel(
              title: t.mcRecIngredients,
              icon: Icons.grid_on_rounded,
              child: McFormColumn(
                gap: 12,
                children: [
                  if (grid) ...[
                    _idField(t.mcRecBrush, _brush, (v) => _brush = v, tags: true),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: const Color(0xFFC6C6C6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var r = 0; r < 3; r++)
                              Row(mainAxisSize: MainAxisSize.min, children: [for (var c = 0; c < 3; c++) _slot(r * 3 + c)]),
                          ],
                        ),
                      ),
                    ),
                    Wrap(
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => _grid.fillRange(0, 9, '')),
                          icon: const Icon(Icons.clear_all_rounded, size: 16),
                          label: Text(t.mcRecClear),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _grid.fillRange(0, 9, _brush)),
                          icon: const Icon(Icons.format_color_fill_rounded, size: 16),
                          label: Text(t.mcRecFill),
                        ),
                      ],
                    ),
                  ] else if (_kind == _Kind.smithing) ...[
                    _idField(t.mcRecTemplate, _template, (v) => _template = v, tags: true),
                    _idField(t.mcRecBase, _base, (v) => _base = v, tags: true),
                    _idField(t.mcRecAddition, _addition, (v) => _addition = v, tags: true),
                  ] else
                    _idField(t.mcRecInput, _input, (v) => _input = v, tags: true),
                  if (_kind.cooking) ...[
                    McSlider(
                      label: t.mcRecXp,
                      value: _xp,
                      min: 0,
                      max: 5,
                      divisions: 50,
                      format: (v) => v.toStringAsFixed(1),
                      onChanged: (v) => setState(() => _xp = v),
                    ),
                    McSlider(
                      label: t.mcRecTime,
                      value: _time.toDouble(),
                      min: 10,
                      max: 1200,
                      format: (v) => t.mcTitleTicks(v.round(), (v / 20).toStringAsFixed(1)),
                      onChanged: (v) => setState(() => _time = v.round()),
                    ),
                  ],
                ],
              ),
            ),
            McPanel(
              title: t.mcRecResult,
              icon: Icons.output_rounded,
              child: McFormColumn(
                gap: 10,
                children: [
                  _idField(t.mcCmdItem, _result, (v) => _result = v),
                  if (!_kind.cooking && _kind != _Kind.smithing)
                    Row(
                      children: [
                        Text(t.mcCmdCount, style: TextStyle(color: luma.textSecondary, fontSize: 12.5)),
                        const Spacer(),
                        McStepper(value: _count, min: 1, max: 99, onChanged: (v) => setState(() => _count = v)),
                      ],
                    ),
                  if (_kind != _Kind.stonecutting && _kind != _Kind.smithing)
                    McField(
                      label: t.mcRecTab,
                      child: McChoice<String>(
                        values: _categories,
                        selected: _category,
                        label: mcPretty,
                        onSelect: (v) => setState(() => _category = v),
                      ),
                    ),
                  McField(
                    label: t.mcRecGroup,
                    child: McTextField(initialValue: _group, monospace: true, onChanged: (v) => setState(() => _group = v)),
                  ),
                  McField(
                    label: t.mcAdvFileName,
                    child: McTextField(initialValue: _name, monospace: true, onChanged: (v) => setState(() => _name = v)),
                  ),
                ],
              ),
            ),
          ],
        ),
        result: McFormColumn(
          children: [
            McCodeBox(
              code: json,
              title: _path,
              maxHeight: 520,
              onSave: () => mcSaveText(context, json, fileName: '${mcSlug(_name, fallback: 'recipe')}.json'),
            ),
            McButton(
              label: t.mcSaveDatapack,
              icon: Icons.folder_zip_rounded,
              primary: false,
              onTap: () => mcSaveBytes(
                context,
                mcDatapackZip(t.mcRecDatapackDesc, {_path: json}),
                fileName: 'luma_recipe_${mcSlug(_name, fallback: 'recipe')}.zip',
                mimeType: 'application/zip',
              ),
            ),
            Text(
              t.mcRecNote('/recipe give @a luma:${mcSlug(_name, fallback: 'recipe')}'),
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
