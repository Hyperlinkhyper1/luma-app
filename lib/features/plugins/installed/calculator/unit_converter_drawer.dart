import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'calc_expression.dart';
import 'unit_conversion.dart';

/// The panel behind the ☰ button in the Calculator's header: pick a category,
/// type a value, and read it back in any other unit — km to miles, °C to °F,
/// kg to pounds, and so on.
class UnitConverterDrawer extends StatefulWidget {
  const UnitConverterDrawer({super.key, required this.onUseValue});

  /// Hands a converted result back to the calculator entry line.
  final ValueChanged<String> onUseValue;

  @override
  State<UnitConverterDrawer> createState() => _UnitConverterDrawerState();
}

class _UnitConverterDrawerState extends State<UnitConverterDrawer> {
  final _input = TextEditingController(text: '1');

  ConvertCategory _category = unitCategories.first;
  late ConvertUnit _from = _category.units.first;

  /// Kilometres to miles out of the box — the conversion people reach for most.
  late ConvertUnit _to = _category.unitById('mi');

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  double? get _value {
    final raw = _input.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  void _selectCategory(ConvertCategory category) {
    setState(() {
      _category = category;
      _from = category.units.first;
      _to = category.units.length > 1 ? category.units[1] : category.units.first;
    });
  }

  void _swap() => setState(() {
        final previous = _from;
        _from = _to;
        _to = previous;
      });

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final value = _value;
    final converted =
        value == null ? null : convertUnits(value, _from, _to);

    return Drawer(
      backgroundColor: luma.surface,
      width: 340,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 18, color: luma.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Convert',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: luma.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                children: [
                  // Eleven categories wrap to a few rows, so they scroll with
                  // the rest rather than pinning that space for good.
                  LumaSegmentedTabs(
                    tabs: [for (final c in unitCategories) c.name],
                    selectedIndex: unitCategories.indexOf(_category),
                    onSelect: (index) => _selectCategory(unitCategories[index]),
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel(luma, 'From'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,\-]'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _inputDecoration(luma),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _UnitDropdown(
                        units: _category.units,
                        selected: _from,
                        onChanged: (unit) => setState(() => _from = unit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Swap units',
                      onPressed: _swap,
                      icon: Icon(
                        Icons.swap_vert_rounded,
                        size: 20,
                        color: luma.accent,
                      ),
                    ),
                  ),
                  _fieldLabel(luma, 'To'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: luma.accentSubtle,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              converted == null
                                  ? '—'
                                  : formatCalcNumber(converted),
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _UnitDropdown(
                        units: _category.units,
                        selected: _to,
                        onChanged: (unit) => setState(() => _to = unit),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LumaPrimaryButton(
                    label: 'Use in calculator',
                    icon: Icons.arrow_forward_rounded,
                    expand: true,
                    onTap: converted == null
                        ? null
                        : () {
                            widget.onUseValue(formatCalcNumber(converted));
                            Navigator.of(context).maybePop();
                          },
                  ),
                  const SizedBox(height: 18),
                  _fieldLabel(luma, 'Every unit'),
                  const SizedBox(height: 4),
                  for (final unit in _category.units)
                    _AllUnitsRow(
                      unit: unit,
                      value: value == null
                          ? null
                          : convertUnits(value, _from, unit),
                      highlighted: unit.id == _to.id,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(LumaPalette luma, String text) => Text(
        text,
        style: TextStyle(
          color: luma.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      );

  InputDecoration _inputDecoration(LumaPalette luma) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color),
        );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: luma.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: border(luma.border),
      focusedBorder: border(luma.accent),
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  const _UnitDropdown({
    required this.units,
    required this.selected,
    required this.onChanged,
  });

  final List<ConvertUnit> units;
  final ConvertUnit selected;
  final ValueChanged<ConvertUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 48,
      width: 108,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected.id,
          isExpanded: true,
          isDense: true,
          dropdownColor: luma.surfaceHover,
          borderRadius: BorderRadius.circular(10),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: luma.textMuted,
          ),
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          onChanged: (id) {
            if (id == null) return;
            onChanged(units.firstWhere((u) => u.id == id));
          },
          selectedItemBuilder: (context) => [
            for (final unit in units)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  unit.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          items: [
            for (final unit in units)
              DropdownMenuItem<String>(
                value: unit.id,
                child: Text(
                  '${unit.name} (${unit.symbol})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textPrimary, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One line of the "every unit" table under the main conversion.
class _AllUnitsRow extends StatelessWidget {
  const _AllUnitsRow({
    required this.unit,
    required this.value,
    required this.highlighted,
  });

  final ConvertUnit unit;
  final double? value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? luma.surfaceHover : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              unit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textSecondary, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value == null ? '—' : formatCalcNumber(value!),
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          SizedBox(
            width: 46,
            child: Text(
              unit.symbol,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: luma.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
