import '../../l10n/current_l.dart';
import '../data/database.dart';
import 'finance_logic.dart';

// ---- Subscription detector --------------------------------------------------

/// A charge that repeats on a steady schedule but isn't tracked as a
/// recurring rule yet.
class SubscriptionCandidate {
  const SubscriptionCandidate({
    required this.key,
    required this.name,
    required this.amountCents,
    required this.cadence,
    required this.lastDate,
    required this.occurrences,
    this.merchantId,
    this.categoryId,
  });

  /// Stable identity used to remember a dismissal ("m:12" or "n:netflix").
  final String key;
  final String name;

  /// The most recent charge, which is what the next one will likely cost.
  final int amountCents;
  final Cadence cadence;
  final DateTime lastDate;
  final int occurrences;
  final int? merchantId;
  final int? categoryId;

  DateTime get nextDue => advanceDate(lastDate, cadence);
}

/// Scans expenses for charges that repeat weekly or monthly at a similar
/// amount and are still running, skipping anything an existing recurring
/// rule already covers and any key in [dismissed].
///
/// Charges are grouped by merchant, or by their note when they have none
/// (digits stripped, so "Order 1234" and "Order 5678" group together).
List<SubscriptionCandidate> detectSubscriptions({
  required Iterable<FinanceTransaction> txns,
  required Iterable<RecurringRule> rules,
  required Map<int, String> merchantNames,
  required DateTime now,
  Set<String> dismissed = const {},
}) {
  final trackedMerchants = {
    for (final r in rules)
      if (r.merchantId != null) r.merchantId!,
  };
  final trackedNames = {for (final r in rules) _normalize(r.name)};

  final groups = <String, List<FinanceTransaction>>{};
  final since = now.subtract(const Duration(days: 400));
  for (final t in txns) {
    if (t.kind != TxnKind.expense || t.date.isBefore(since)) continue;
    // Entries a rule booked carry the rule's name as their note.
    if (t.note != null && trackedNames.contains(_normalize(t.note!))) continue;
    final String key;
    if (t.merchantId != null) {
      if (trackedMerchants.contains(t.merchantId)) continue;
      key = 'm:${t.merchantId}';
    } else {
      final n = _normalize(t.note ?? '');
      if (n.isEmpty) continue;
      key = 'n:$n';
    }
    groups.putIfAbsent(key, () => []).add(t);
  }

  final found = <SubscriptionCandidate>[];
  groups.forEach((key, list) {
    if (dismissed.contains(key)) return;
    list.sort((a, b) => a.date.compareTo(b.date));
    // One charge per day: a split payment isn't a second occurrence.
    final daily = <FinanceTransaction>[];
    for (final t in list) {
      if (daily.isNotEmpty && _sameDay(daily.last.date, t.date)) continue;
      daily.add(t);
    }
    if (daily.length < 3) return;

    final gaps = [
      for (var i = 1; i < daily.length; i++)
        _dayDiff(daily[i - 1].date, daily[i].date),
    ];
    final medianGap = _median(gaps);
    final Cadence cadence;
    final int minGap, maxGap;
    if (medianGap >= 6 && medianGap <= 8) {
      cadence = Cadence.weekly;
      minGap = 5;
      maxGap = 9;
      if (daily.length < 4) return;
    } else if (medianGap >= 26 && medianGap <= 35) {
      cadence = Cadence.monthly;
      minGap = 24;
      maxGap = 38;
    } else {
      return;
    }
    final steady = gaps.where((g) => g >= minGap && g <= maxGap).length;
    if (steady < gaps.length * 0.75) return;

    final amounts = [for (final t in daily) t.amountCents];
    final medianAmount = _median(amounts);
    final similar = amounts
        .where((a) => (a - medianAmount).abs() <= medianAmount * 0.15)
        .length;
    if (similar < amounts.length * 0.75) return;

    // A subscription that stopped charging has been cancelled.
    final last = daily.last;
    if (_dayDiff(last.date, now) > medianGap * 1.6) return;

    final merchantId = last.merchantId;
    found.add(
      SubscriptionCandidate(
        key: key,
        name: merchantId != null
            ? merchantNames[merchantId] ?? currentL.financeUnknownMerchant
            : last.note!.trim(),
        amountCents: last.amountCents,
        cadence: cadence,
        lastDate: DateTime(last.date.year, last.date.month, last.date.day),
        occurrences: daily.length,
        merchantId: merchantId,
        categoryId: last.categoryId,
      ),
    );
  });
  found.sort((a, b) => b.amountCents.compareTo(a.amountCents));
  return found;
}

String _normalize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[0-9]'), '')
    .replaceAll(RegExp(r'[^a-zÀ-ɏ]+'), ' ')
    .trim();

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _dayDiff(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

// ---- Period reports ---------------------------------------------------------

/// Whether a report covers one month or one whole year.
enum ReportSpan { month, year }

/// A calendar month or year.
class ReportPeriod {
  ReportPeriod(this.span, DateTime anchor)
    : start = span == ReportSpan.month
          ? DateTime(anchor.year, anchor.month, 1)
          : DateTime(anchor.year, 1, 1);

  final ReportSpan span;
  final DateTime start;

  DateTime get end => span == ReportSpan.month
      ? DateTime(start.year, start.month + 1, 1)
      : DateTime(start.year + 1, 1, 1);

  ReportPeriod get previous => ReportPeriod(
    span,
    span == ReportSpan.month
        ? DateTime(start.year, start.month - 1, 1)
        : DateTime(start.year - 1, 1, 1),
  );

  ReportPeriod get next => ReportPeriod(span, end);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

/// Spending on one merchant (or free-text payee) within a period.
class MerchantTotal {
  const MerchantTotal(this.name, this.cents, this.count);
  final String name;
  final int cents;
  final int count;
}

/// Income, spending and where it went for one [ReportPeriod]. Allocations
/// only move money between the user's own balances, so they are neither.
class PeriodReport {
  PeriodReport._({
    required this.period,
    required this.incomeCents,
    required this.expenseCents,
    required this.byCategory,
    required this.previousByCategory,
    required this.previousExpenseCents,
    required this.topMerchants,
    required this.transactions,
  });

  final ReportPeriod period;
  final int incomeCents;
  final int expenseCents;

  /// Expense per category id (null = uncategorized).
  final Map<int?, int> byCategory;
  final Map<int?, int> previousByCategory;
  final int previousExpenseCents;
  final List<MerchantTotal> topMerchants;

  /// Every entry in the period, newest first.
  final List<FinanceTransaction> transactions;

  int get netCents => incomeCents - expenseCents;

  /// Share of income that wasn't spent, or null without income.
  double? get savingsRate => incomeCents <= 0 ? null : netCents / incomeCents;

  factory PeriodReport.build({
    required ReportPeriod period,
    required Iterable<FinanceTransaction> txns,
    required Map<int, String> merchantNames,
    int topMerchantCount = 5,
  }) {
    final previous = period.previous;
    var income = 0, expense = 0, prevExpense = 0;
    final byCategory = <int?, int>{};
    final prevByCategory = <int?, int>{};
    final merchants = <String, (int, int)>{};
    final inPeriod = <FinanceTransaction>[];

    for (final t in txns) {
      if (period.contains(t.date)) {
        inPeriod.add(t);
        if (t.kind == TxnKind.income) income += t.amountCents;
        if (t.kind != TxnKind.expense) continue;
        expense += t.amountCents;
        byCategory[t.categoryId] =
            (byCategory[t.categoryId] ?? 0) + t.amountCents;
        final name = t.merchantId != null
            ? merchantNames[t.merchantId]
            : (t.note?.trim().isNotEmpty ?? false)
            ? t.note!.trim()
            : null;
        if (name == null) continue;
        final (cents, count) = merchants[name] ?? (0, 0);
        merchants[name] = (cents + t.amountCents, count + 1);
      } else if (previous.contains(t.date) && t.kind == TxnKind.expense) {
        prevExpense += t.amountCents;
        prevByCategory[t.categoryId] =
            (prevByCategory[t.categoryId] ?? 0) + t.amountCents;
      }
    }

    final top = [
      for (final e in merchants.entries)
        MerchantTotal(e.key, e.value.$1, e.value.$2),
    ]..sort((a, b) => b.cents.compareTo(a.cents));
    inPeriod.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });

    return PeriodReport._(
      period: period,
      incomeCents: income,
      expenseCents: expense,
      byCategory: byCategory,
      previousByCategory: prevByCategory,
      previousExpenseCents: prevExpense,
      topMerchants: top.take(topMerchantCount).toList(),
      transactions: inPeriod,
    );
  }
}

// ---- CSV export -------------------------------------------------------------

/// Renders [txns] as RFC 4180 CSV with a header row. Amounts are signed
/// decimals with a dot ("-12.50"), so spreadsheets read them as numbers;
/// allocations are negative from the main balance's point of view.
String transactionsToCsv({
  required Iterable<FinanceTransaction> txns,
  required Map<int, String> categoryNames,
  required Map<int, String> merchantNames,
  required Map<int, String> potNames,
}) {
  final out = StringBuffer('Date,Type,Amount,Category,Merchant,Pot,Note\r\n');
  for (final t in txns) {
    final signed = t.kind == TxnKind.income ? t.amountCents : -t.amountCents;
    final d = t.date;
    out.write(
      [
        '${d.year}-${_two(d.month)}-${_two(d.day)}',
        t.kind.name,
        _decimal(signed),
        t.categoryId == null ? '' : categoryNames[t.categoryId] ?? '',
        t.merchantId == null ? '' : merchantNames[t.merchantId] ?? '',
        t.potId == null ? '' : potNames[t.potId] ?? '',
        t.note ?? '',
      ].map(_csvField).join(','),
    );
    out.write('\r\n');
  }
  return out.toString();
}

String _two(int n) => n.toString().padLeft(2, '0');

String _decimal(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${_two(abs % 100)}';
}

String _csvField(String value) {
  // A leading =, + or @ makes spreadsheets run the cell as a formula. A
  // leading - is left alone: it is how every negative amount starts.
  final safe = RegExp(r'^[=+@]').hasMatch(value) ? "'$value" : value;
  if (!safe.contains(RegExp(r'[",\r\n]'))) return safe;
  return '"${safe.replaceAll('"', '""')}"';
}
