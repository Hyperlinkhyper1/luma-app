import 'package:flutter/material.dart';

import '../../../../../../l10n/app_localizations.dart';
import '../../../../../../theme/luma_theme.dart';
import '../../logic/pta/pta_binas.dart';

Future<void> showPtaBinas(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _BinasDialog(),
  );
}

class _BinasDialog extends StatelessWidget {
  const _BinasDialog();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final sheets = binasSheets();
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: size.height * 0.88,
        ),
        child: DefaultTabController(
          length: sheets.length,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: luma.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t.schoolPtaBinas,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final s in sheets) Tab(text: s.code)],
              ),
              Flexible(
                child: TabBarView(
                  children: [for (final s in sheets) _SheetView(sheet: s)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Text(
                  t.schoolPtaBinasNote,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetView extends StatelessWidget {
  const _SheetView({required this.sheet});
  final BinasSheet sheet;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final grid = sheet.code == '45A';
    final headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: luma.textPrimary,
      fontSize: 12.5,
    );
    final cellStyle = TextStyle(color: luma.textSecondary, fontSize: 12.5);
    Color cellColor(String v) => switch (v) {
          's' => luma.accent.withValues(alpha: 0.22),
          'm' => luma.warning.withValues(alpha: 0.18),
          _ => Colors.transparent,
        };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${sheet.code} · ${sheet.title}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: grid
                  ? const FixedColumnWidth(74)
                  : const IntrinsicColumnWidth(),
              border: TableBorder.all(color: luma.border, width: 0.8),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: luma.surfaceHover),
                  children: [
                    for (final h in sheet.headers)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        child: Text(h, style: headerStyle),
                      ),
                  ],
                ),
                for (final row in sheet.rows)
                  TableRow(
                    children: [
                      for (var i = 0; i < row.length; i++)
                        Container(
                          color: grid && i > 0
                              ? cellColor(row[i])
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          alignment: grid && i > 0
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: Text(
                            row[i],
                            style: i == 0 ? headerStyle : cellStyle,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(sheet.note, style: TextStyle(color: luma.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
