import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/widgets.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_scope.dart';
import '../logic/insights.dart';
import '../logic/money.dart';
import 'lookups.dart';

/// Monthly and yearly reports: income against spending, where the money
/// went compared with the period before, top merchants, and a CSV export.
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  ReportPeriod _period = ReportPeriod(ReportSpan.month, DateTime.now());
  bool _exporting = false;

  void _setSpan(ReportSpan span) {
    if (span == _period.span) return;
    final now = DateTime.now();
    // Keep the year in view; land on its current month when there is one.
    final anchor = span == ReportSpan.month && _period.start.year == now.year
        ? now
        : _period.start;
    setState(() => _period = ReportPeriod(span, anchor));
  }

  String _label(ReportPeriod p) => p.span == ReportSpan.month
      ? DateFormat('MMMM y').format(p.start)
      : '${p.start.year}';

  Future<void> _export(
    PeriodReport report,
    List<Category> categories,
    List<Merchant> merchants,
    List<Pot> pots,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (report.transactions.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nothing to export in this period.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final csv = transactionsToCsv(
        txns: report.transactions,
        categoryNames: {for (final c in categories) c.id: c.name},
        merchantNames: {for (final m in merchants) m.id: m.name},
        potNames: {for (final p in pots) p.id: p.name},
      );
      final start = report.period.start;
      final stamp = report.period.span == ReportSpan.month
          ? '${start.year}-${start.month.toString().padLeft(2, '0')}'
          : '${start.year}';
      // A BOM lets Excel open the file as UTF-8 (€, accents) instead of
      // guessing the system code page.
      final bytes = utf8.encode('﻿$csv');
      final path = await FilePicker.saveFile(
        dialogTitle: 'Export transactions',
        fileName: 'luma-finance-$stamp.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
      if (path != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${report.transactions.length} transactions.',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    final luma = context.luma;
    return StreamData<List<FinanceTransaction>>(
      stream: repo.watchTransactions(),
      builder: (context, txns) => StreamData<List<Category>>(
        stream: repo.watchCategories(),
        builder: (context, categories) => StreamData<List<Merchant>>(
          stream: repo.watchMerchants(),
          builder: (context, merchants) => StreamData<List<Pot>>(
            stream: repo.watchPots(),
            builder: (context, pots) {
              final merchantNames = {for (final m in merchants) m.id: m.name};
              final report = PeriodReport.build(
                period: _period,
                txns: txns,
                merchantNames: merchantNames,
              );
              final isCurrent = _period.contains(DateTime.now());
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            LumaSegmentedTabs(
                              tabs: const ['Month', 'Year'],
                              selectedIndex: _period.span == ReportSpan.month
                                  ? 0
                                  : 1,
                              onSelect: (i) => _setSpan(
                                i == 0 ? ReportSpan.month : ReportSpan.year,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Previous',
                              icon: Icon(
                                Icons.chevron_left_rounded,
                                color: luma.textSecondary,
                              ),
                              onPressed: () =>
                                  setState(() => _period = _period.previous),
                            ),
                            Text(
                              _label(_period),
                              style: TextStyle(
                                color: luma.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Next',
                              icon: Icon(
                                Icons.chevron_right_rounded,
                                color: isCurrent
                                    ? luma.textMuted
                                    : luma.textSecondary,
                              ),
                              onPressed: isCurrent
                                  ? null
                                  : () =>
                                        setState(() => _period = _period.next),
                            ),
                          ],
                        ),
                        LumaGhostButton(
                          label: _exporting ? 'Exporting…' : 'Export CSV',
                          icon: Icons.download_rounded,
                          onTap: _exporting
                              ? null
                              : () => _export(
                                  report,
                                  categories,
                                  merchants,
                                  pots,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Summary(report: report),
                    const SizedBox(height: 20),
                    _CategoryBreakdown(report: report, categories: categories),
                    if (report.topMerchants.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _TopMerchants(report: report),
                    ],
                    if (_period.span == ReportSpan.year) ...[
                      const SizedBox(height: 20),
                      _MonthByMonth(
                        year: _period.start.year,
                        txns: txns,
                        merchantNames: merchantNames,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.report});
  final PeriodReport report;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final rate = report.savingsRate;
    final prev = report.previousExpenseCents;
    final spendDelta = report.expenseCents - prev;
    final previousName = report.period.span == ReportSpan.month
        ? 'last month'
        : 'last year';

    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth < 560 ? 2 : 4;
        final width = (constraints.maxWidth - 12 * (perRow - 1)) / perRow;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Stat(
              width: width,
              label: 'Income',
              value: formatCents(report.incomeCents),
              color: luma.success,
            ),
            _Stat(
              width: width,
              label: 'Spent',
              value: formatCents(report.expenseCents),
              color: luma.danger,
              footnote: prev == 0
                  ? null
                  : '${formatSignedCents(spendDelta)} vs $previousName',
            ),
            _Stat(
              width: width,
              label: 'Net',
              value: formatSignedCents(report.netCents),
              color: report.netCents >= 0 ? luma.success : luma.danger,
            ),
            _Stat(
              width: width,
              label: 'Savings rate',
              value: rate == null ? '—' : '${(rate * 100).round()}%',
              color: rate == null
                  ? luma.textPrimary
                  : rate >= 0
                  ? luma.success
                  : luma.danger,
              footnote: 'Share of income not spent',
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
    this.footnote,
  });
  final double width;
  final String label;
  final String value;
  final Color color;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SizedBox(
      width: width,
      child: LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: luma.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (footnote != null) ...[
              const SizedBox(height: 2),
              Text(
                footnote!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textMuted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.report, required this.categories});
  final PeriodReport report;
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final catById = {for (final c in categories) c.id: c};
    final ids = {...report.byCategory.keys, ...report.previousByCategory.keys};
    final rows = ids.toList()
      ..sort(
        (a, b) =>
            (report.byCategory[b] ?? 0).compareTo(report.byCategory[a] ?? 0),
      );
    final isMonth = report.period.span == ReportSpan.month;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Spending by category',
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Compared with ${isMonth ? 'the month' : 'the year'} before.',
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (rows.isEmpty)
            Text(
              'No spending in this period.',
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            )
          else
            for (final id in rows) ...[
              _CategoryRow(
                category: id == null ? null : catById[id],
                cents: report.byCategory[id] ?? 0,
                previousCents: report.previousByCategory[id] ?? 0,
                totalCents: report.expenseCents,
                budgetCents: isMonth && id != null
                    ? catById[id]?.monthlyBudgetCents
                    : null,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.cents,
    required this.previousCents,
    required this.totalCents,
    this.budgetCents,
  });
  final Category? category;
  final int cents;
  final int previousCents;
  final int totalCents;
  final int? budgetCents;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = category != null
        ? Color(category!.colorValue)
        : luma.textMuted;
    final delta = cents - previousCents;
    final share = totalCents <= 0 ? 0.0 : cents / totalCents;
    final budget = budgetCents;
    final details = [
      '${(share * 100).round()}% of spending',
      if (budget != null && budget > 0)
        cents > budget
            ? '${formatCents(cents - budget)} over budget'
            : 'within ${formatCents(budget)} budget',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              category != null
                  ? materialIcon(category!.iconCodepoint)
                  : Icons.help_outline_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category?.name ?? 'Uncategorized',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: luma.textPrimary, fontSize: 13),
              ),
            ),
            if (previousCents > 0 || cents > 0)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      delta > 0
                          ? Icons.arrow_upward_rounded
                          : delta < 0
                          ? Icons.arrow_downward_rounded
                          : Icons.remove_rounded,
                      size: 12,
                      color: delta > 0
                          ? luma.danger
                          : delta < 0
                          ? luma.success
                          : luma.textMuted,
                    ),
                    Text(
                      formatCents(delta.abs()),
                      style: TextStyle(color: luma.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            Text(
              formatCents(cents),
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: luma.surfaceHover,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          details,
          style: TextStyle(
            color: budget != null && budget > 0 && cents > budget
                ? luma.danger
                : luma.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _TopMerchants extends StatelessWidget {
  const _TopMerchants({required this.report});
  final PeriodReport report;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Top merchants',
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < report.topMerchants.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: luma.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      report.topMerchants[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textPrimary),
                    ),
                  ),
                  Text(
                    '${report.topMerchants[i].count}×',
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatCents(report.topMerchants[i].cents),
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontWeight: FontWeight.w600,
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

class _MonthByMonth extends StatelessWidget {
  const _MonthByMonth({
    required this.year,
    required this.txns,
    required this.merchantNames,
  });
  final int year;
  final List<FinanceTransaction> txns;
  final Map<int, String> merchantNames;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final now = DateTime.now();
    final months = [
      for (var m = 1; m <= 12; m++)
        if (DateTime(year, m).isBefore(DateTime(now.year, now.month + 1)))
          PeriodReport.build(
            period: ReportPeriod(ReportSpan.month, DateTime(year, m)),
            txns: txns,
            merchantNames: merchantNames,
            topMerchantCount: 0,
          ),
    ];
    final biggest = months.fold<int>(
      1,
      (m, r) =>
          [m, r.incomeCents, r.expenseCents].reduce((a, b) => a > b ? a : b),
    );

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Month by month',
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (months.isEmpty)
            Text(
              'This year hasn\'t started yet.',
              style: TextStyle(color: luma.textMuted, fontSize: 13),
            ),
          for (final r in months)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      DateFormat('MMM').format(r.period.start),
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _Bar(
                          fraction: r.incomeCents / biggest,
                          color: luma.success,
                        ),
                        const SizedBox(height: 3),
                        _Bar(
                          fraction: r.expenseCents / biggest,
                          color: luma.danger,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: Text(
                      formatSignedCents(r.netCents),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: r.netCents >= 0 ? luma.success : luma.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: LinearProgressIndicator(
      value: fraction.clamp(0.0, 1.0),
      minHeight: 5,
      backgroundColor: context.luma.surfaceHover,
      valueColor: AlwaysStoppedAnimation(color),
    ),
  );
}
