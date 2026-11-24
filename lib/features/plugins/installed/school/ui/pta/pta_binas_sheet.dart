import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../theme/luma_theme.dart';
import '../../logic/pta/pta_binas.dart';
import '../../logic/pta/pta_chemistry.dart';

const _tableLabels = {
  '45A': 'Oplosbaarheid',
  '48': 'Redox',
  '49': 'Zuren en basen',
  '52A': 'Indicatoren',
  '65A': 'Vlamkleuren',
  '65B': 'Kleuren',
};

final _flameColors = {
  for (final entry in flames.entries)
    entry.key.formula: Color(entry.value.argb),
  'Li⁺': const Color(0xFFCE315A),
  'Sr²⁺': const Color(0xFFF04D45),
};

const _formulaGlyphs = '₀₁₂₃₄₅₆₇₈₉⁰¹²³⁴⁵⁶⁷⁸⁹₊⁺₋⁻−';
const _keyboardGlyphs = '01234567890123456789++---';

String _searchable(String value) => String.fromCharCodes(
  value.toLowerCase().codeUnits.map((unit) {
    final index = _formulaGlyphs.indexOf(String.fromCharCode(unit));
    return index < 0 ? unit : _keyboardGlyphs.codeUnitAt(index);
  }),
);

Future<void> showPtaBinas(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _BinasDialog(),
  );
}

class _BinasDialog extends StatefulWidget {
  const _BinasDialog();

  @override
  State<_BinasDialog> createState() => _BinasDialogState();
}

class _BinasDialogState extends State<_BinasDialog> {
  final _sheets = binasSheets();
  final _vertical = ScrollController(keepScrollOffset: false);
  var _active = 0;

  @override
  void dispose() {
    _vertical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 620;
    final gap = compact ? 14.0 : 24.0;
    final inset = compact ? 12.0 : 24.0;
    final sheet = _sheets[_active];

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.fromLTRB(
        inset,
        (size.height * 0.06).clamp(inset, 52.0),
        inset,
        inset,
      ),
      backgroundColor: luma.surface,
      clipBehavior: Clip.antiAlias,
      child: PrimaryScrollController(
        controller: _vertical,
        child: SizedBox(
          width: 880,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gap, 12, gap - 4, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: luma.accent,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t.schoolPtaBinas,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    autofocus: true,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gap, 0, gap, 14),
              child: _TableSelector(
                sheets: _sheets,
                active: _active,
                onSelected: (index) => setState(() => _active = index),
              ),
            ),
            Divider(height: 1, color: luma.border),
            Flexible(
              child: _SheetView(
                key: ValueKey(sheet.code),
                sheet: sheet,
                gap: gap,
              ),
            ),
            Divider(height: 1, color: luma.border),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gap, vertical: 10),
              child: Text(
                t.schoolPtaBinasNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: luma.textSecondary,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _TableSelector extends StatelessWidget {
  const _TableSelector({
    required this.sheets,
    required this.active,
    required this.onSelected,
  });

  final List<BinasSheet> sheets;
  final int active;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(10);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720 ||
            MediaQuery.textScalerOf(context).scale(14) > 18) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: luma.background,
              border: Border.all(color: luma.border),
              borderRadius: radius,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: active,
                borderRadius: radius,
                dropdownColor: luma.surface,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: [
                  for (final (index, sheet) in sheets.indexed)
                    DropdownMenuItem(
                      value: index,
                      child: Text(
                        '${sheet.code} · ${_tableLabels[sheet.code]}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (index) {
                  if (index != null) onSelected(index);
                },
              ),
            ),
          );
        }

        return Row(
          spacing: 8,
          children: [
            for (final (index, sheet) in sheets.indexed)
              Expanded(
                child: Semantics(
                  selected: index == active,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      foregroundColor: luma.textPrimary,
                      backgroundColor: index == active
                          ? luma.accentSubtle
                          : luma.background,
                      side: BorderSide(
                        color: index == active ? luma.accent : luma.border,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: radius),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => onSelected(index),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheet.code,
                          style: text.labelMedium?.copyWith(
                            color: index == active
                                ? luma.accent
                                : luma.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tableLabels[sheet.code]!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium?.copyWith(
                            color: luma.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SheetView extends StatefulWidget {
  const _SheetView({super.key, required this.sheet, required this.gap});

  final BinasSheet sheet;
  final double gap;

  @override
  State<_SheetView> createState() => _SheetViewState();
}

class _SheetViewState extends State<_SheetView> {
  final _filter = TextEditingController();
  final _horizontal = ScrollController();
  var _matrixFocus = false;

  @override
  void dispose() {
    _filter.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _updateFilter() {
    if (_horizontal.hasClients) _horizontal.jumpTo(0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final text = Theme.of(context).textTheme;
    final sheet = widget.sheet;
    final grid = sheet.code == '45A';
    final terms = _searchable(_filter.text).trim().split(RegExp(r'\s+'))
      ..removeWhere((term) => term.isEmpty);
    bool matches(String value, String term) =>
        _searchable(value).contains(term);
    var columns = List.generate(sheet.headers.length, (index) => index);
    var rows = sheet.rows;
    if (terms.isNotEmpty && grid) {
      final matchingColumns = [
        for (final column in columns.skip(1))
          if (terms.any((term) => matches(sheet.headers[column], term))) column,
      ];
      final matchingRows = [
        for (final row in sheet.rows)
          if (terms.any((term) => matches(row.first, term))) row,
      ];
      final hasAllTerms = terms.every(
        (term) =>
            matchingColumns.any(
              (column) => matches(sheet.headers[column], term),
            ) ||
            matchingRows.any((row) => matches(row.first, term)),
      );
      if (!hasAllTerms) {
        rows = const [];
      } else {
        if (matchingColumns.isNotEmpty) columns = [0, ...matchingColumns];
        if (matchingRows.isNotEmpty) rows = matchingRows;
      }
    } else if (terms.isNotEmpty) {
      rows = rows.where((row) {
        final content = _searchable(row.join(' '));
        return terms.every(content.contains);
      }).toList();
    }

    final search = TextField(
      controller: _filter,
      onChanged: (_) => _updateFilter(),
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: t.commonSearchHint,
        hintStyle: TextStyle(color: luma.textSecondary),
        prefixIcon: const Icon(Icons.search_rounded, size: 19),
        suffixIcon: _filter.text.isEmpty
            ? null
            : IconButton(
                tooltip: t.commonClear,
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _filter.clear();
                  _updateFilter();
                },
              ),
      ),
    );
    final heading = Semantics(
      header: true,
      child: Text(
        sheet.title,
        style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );

    return ColoredBox(
      color: luma.background,
      child: Scrollbar(
        controller: PrimaryScrollController.of(context),
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
        primary: true,
        padding: EdgeInsets.fromLTRB(widget.gap, 16, widget.gap, widget.gap),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gridColumnWidths = [
              if (grid)
                for (final column in columns)
                  math.max(
                    56.0,
                    TextPainter.computeWidth(
                          text: TextSpan(
                            text: sheet.headers[column],
                            style: _tableHeaderStyle(context),
                          ),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        ).ceilToDouble() +
                        12,
                  ),
            ];
            final gridWidth = gridColumnWidths.fold(0.0, (a, b) => a + b);
            final scrollsHorizontally =
                grid && gridWidth > constraints.maxWidth;
            final table = _ReferenceTable(
              sheet: sheet,
              columns: columns,
              rows: rows,
              gridColumnWidths: gridColumnWidths,
              focused: _matrixFocus && scrollsHorizontally,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (constraints.maxWidth >= 630)
                  Row(
                    children: [
                      Expanded(child: heading),
                      const SizedBox(width: 20),
                      SizedBox(width: 240, child: search),
                    ],
                  )
                else ...[
                  heading,
                  const SizedBox(height: 10),
                  search,
                ],
                const SizedBox(height: 14),
                if (grid && rows.isNotEmpty) ...[
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      for (final entry in binasSolubilityLabels.entries)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SolubilityMark(
                              value: entry.key,
                              showMeaning: false,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                entry.value,
                                style: text.bodySmall?.copyWith(
                                  color: luma.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (rows.isEmpty)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        t.commonNoResults,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: luma.textSecondary,
                        ),
                      ),
                    ),
                  )
                else if (scrollsHorizontally)
                  Scrollbar(
                    controller: _horizontal,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    scrollbarOrientation: ScrollbarOrientation.top,
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(top: 12),
                      child: FocusableActionDetector(
                        onShowFocusHighlight: (focused) {
                          setState(() => _matrixFocus = focused);
                        },
                        shortcuts: const {
                          SingleActivator(LogicalKeyboardKey.arrowLeft):
                              ScrollIntent(direction: AxisDirection.left),
                          SingleActivator(LogicalKeyboardKey.arrowRight):
                              ScrollIntent(direction: AxisDirection.right),
                        },
                        child: SizedBox(width: gridWidth, child: table),
                      ),
                    ),
                  )
                else
                  table,
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: luma.accentSubtle,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: luma.accent,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(sheet.note, style: text.bodySmall),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
        ),
      ),
    );
  }
}

TextStyle? _tableHeaderStyle(BuildContext context) => Theme.of(
  context,
).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700);

class _ReferenceTable extends StatelessWidget {
  const _ReferenceTable({
    required this.sheet,
    required this.columns,
    required this.rows,
    required this.gridColumnWidths,
    required this.focused,
  });

  final BinasSheet sheet;
  final List<int> columns;
  final List<List<String>> rows;
  final List<double> gridColumnWidths;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final theme = Theme.of(context);
    final grid = sheet.code == '45A';
    final flame = sheet.code == '65A';
    final compact = MediaQuery.sizeOf(context).width < 620;
    final radius = BorderRadius.circular(10);
    final side = BorderSide(color: luma.border);
    final outline = focused ? BorderSide(color: luma.accent) : side;
    final headerStyle = _tableHeaderStyle(context);
    final valueStyle = theme.textTheme.bodyMedium;
    final padding = EdgeInsets.symmetric(
      horizontal: grid || compact ? 6 : 12,
      vertical: 9,
    );
    final widths = switch (sheet.code) {
      '48' => [3.0, 3.0, 1.4],
      '49' => [1.3, 1.55, 1.1, 0.8, 1.1],
      '52A' => [1.5, 1.18, 1.0, 1.0],
      '65A' => [1.3, 2.7],
      '65B' => [1.2, 1.6, 1.2],
      _ => gridColumnWidths,
    };
    bool numeric(int column) => switch (sheet.code) {
      '48' => column == 2,
      '49' => column >= 2,
      _ => false,
    };
    TextAlign alignment(int column) => grid
        ? TextAlign.center
        : numeric(column)
        ? TextAlign.end
        : TextAlign.start;

    return ClipRRect(
      borderRadius: radius,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        defaultColumnWidth: const FlexColumnWidth(),
        columnWidths: {
          for (final (index, width) in widths.indexed)
            index: FlexColumnWidth(width),
        },
        border: TableBorder(
          top: outline,
          bottom: outline,
          left: outline,
          right: outline,
          horizontalInside: side,
          verticalInside: grid ? side : BorderSide.none,
          borderRadius: radius,
        ),
        children: [
          TableRow(
            decoration: BoxDecoration(color: luma.surfaceHover),
            children: [
              for (final column in columns)
                Padding(
                  padding: padding,
                  child: Semantics(
                    header: true,
                    child: Text(
                      sheet.headers[column],
                      textAlign: alignment(column),
                      softWrap: !grid,
                      style: headerStyle,
                    ),
                  ),
                ),
            ],
          ),
          for (final (index, row) in rows.indexed)
            TableRow(
              decoration: BoxDecoration(
                color: index.isEven ? luma.surface : luma.background,
              ),
              children: [
                for (final column in columns)
                  Padding(
                    padding: padding,
                    child: grid && column > 0
                        ? Center(child: _SolubilityMark(value: row[column]))
                        : flame && column == 1
                        ? Row(
                            children: [
                              Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: _flameColors[row.first],
                                  border: Border.all(
                                    color: luma.textSecondary,
                                    width: 0.8,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(row[column], style: valueStyle),
                              ),
                            ],
                          )
                        : Text(
                            row[column],
                            textAlign: alignment(column),
                            style: column == 0
                                ? headerStyle
                                : numeric(column)
                                ? valueStyle?.copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  )
                                : valueStyle,
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SolubilityMark extends StatelessWidget {
  const _SolubilityMark({required this.value, this.showMeaning = true});

  final String value;
  final bool showMeaning;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = switch (value) {
      'g' => luma.success.withValues(alpha: 0.12),
      'm' => luma.warning.withValues(alpha: 0.19),
      's' => luma.danger.withValues(alpha: 0.21),
      _ => luma.surfaceHover,
    };
    return Container(
      constraints: const BoxConstraints(minWidth: 23),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        value,
        semanticsLabel: showMeaning ? binasSolubilityLabels[value] : null,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
