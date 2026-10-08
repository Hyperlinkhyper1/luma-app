import '../../l10n/current_l.dart';
import '../data/database.dart';
import 'finance_logic.dart';

// ---- Category budgets -------------------------------------------------------

/// How much of one category's monthly budget has been spent.
class BudgetUsage {
  const BudgetUsage({
    required this.category,
    required this.budgetCents,
    required this.spentCents,
  });

  final Category category;
  final int budgetCents;
  final int spentCents;

  double get fraction => budgetCents <= 0 ? 0 : spentCents / budgetCents;
  int get remainingCents => budgetCents - spentCents;
  bool get isOver => spentCents > budgetCents;

  /// 80% or more used, but not over yet.
  bool get isNear => !isOver && fraction >= 0.8;
}

/// Spending against every budgeted category for the calendar month that
/// contains [month]. Expenses paid from a pot count too: a budget limits what
/// a category costs, whichever balance paid for it.
List<BudgetUsage> budgetUsage({
  required Iterable<Category> categories,
  required Iterable<FinanceTransaction> txns,
  required DateTime month,
}) {
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final spent = <int, int>{};
  for (final t in txns) {
    if (t.kind != TxnKind.expense || t.categoryId == null) continue;
    if (t.date.isBefore(start) || !t.date.isBefore(end)) continue;
    spent[t.categoryId!] = (spent[t.categoryId!] ?? 0) + t.amountCents;
  }
  final usage = [
    for (final c in categories)
      if ((c.monthlyBudgetCents ?? 0) > 0)
        BudgetUsage(
          category: c,
          budgetCents: c.monthlyBudgetCents!,
          spentCents: spent[c.id] ?? 0,
        ),
  ];
  usage.sort((a, b) => b.fraction.compareTo(a.fraction));
  return usage;
}

// ---- Pot savings goals ------------------------------------------------------

/// Where a pot stands against its savings goal.
class GoalProgress {
  const GoalProgress({
    required this.goalCents,
    required this.balanceCents,
    this.goalDate,
    this.monthsLeft,
    this.monthlyNeededCents,
  });

  final int goalCents;
  final int balanceCents;
  final DateTime? goalDate;

  /// Whole months until [goalDate], at least 1; null without a date.
  final int? monthsLeft;

  /// Top-up per month that reaches the goal by [goalDate]; null without a
  /// date or once the goal is reached.
  final int? monthlyNeededCents;

  double get fraction =>
      goalCents <= 0 ? 0 : (balanceCents / goalCents).clamp(0.0, 1.0);
  bool get reached => balanceCents >= goalCents;
  int get remainingCents =>
      (goalCents - balanceCents) < 0 ? 0 : goalCents - balanceCents;

  /// The date has passed and the goal still isn't met.
  bool isOverdue(DateTime now) =>
      !reached && goalDate != null && goalDate!.isBefore(_day(now));
}

/// Goal progress for [pot], or null when the pot has no goal.
GoalProgress? goalProgress(Pot pot, int balanceCents, DateTime now) {
  final goal = pot.goalCents;
  if (goal == null || goal <= 0) return null;
  final date = pot.goalDate;
  if (date == null) {
    return GoalProgress(goalCents: goal, balanceCents: balanceCents);
  }
  final months = monthsUntil(now, date);
  final remaining = goal - balanceCents;
  return GoalProgress(
    goalCents: goal,
    balanceCents: balanceCents,
    goalDate: date,
    monthsLeft: months,
    monthlyNeededCents: remaining <= 0
        ? null
        : (remaining + months - 1) ~/ months,
  );
}

/// Calendar months from [from] to [to], counting a partial month as a whole
/// one and never less than 1 (a goal due this month needs one top-up).
int monthsUntil(DateTime from, DateTime to) {
  var months = (to.year - from.year) * 12 + (to.month - from.month);
  if (to.day > from.day) months++;
  return months < 1 ? 1 : months;
}

// ---- Cash-flow forecast -----------------------------------------------------

/// One scheduled movement of the main balance inside a forecast.
class ForecastEvent {
  const ForecastEvent(this.date, this.label, this.deltaCents);
  final DateTime date;
  final String label;

  /// Signed change to the main balance.
  final int deltaCents;
}

/// The projected main balance over the coming days.
class CashFlowForecast {
  const CashFlowForecast({
    required this.start,
    required this.dailyCents,
    required this.events,
  });

  final DateTime start;

  /// Closing main balance for each day, [start] first.
  final List<int> dailyCents;
  final List<ForecastEvent> events;

  int get endCents => dailyCents.last;

  int get lowestCents => dailyCents.reduce((a, b) => a < b ? a : b);

  /// The first day the balance reaches its lowest point.
  DateTime get lowestDate =>
      start.add(Duration(days: dailyCents.indexOf(lowestCents)));

  /// The first day the balance drops below zero, or null if it never does.
  DateTime? get firstNegativeDate {
    final i = dailyCents.indexWhere((c) => c < 0);
    return i < 0 ? null : start.add(Duration(days: i));
  }
}

/// Projects the main (unallocated) balance [days] days ahead of [now] from
/// the active recurring rules and allocation rules.
///
/// Rules tied to a pot move that pot's balance, not the main one, so they
/// are left out. A percentage allocation takes its share of the projected
/// main balance on the day it fires, the same way [allocationAmountCents]
/// sizes it for real.
CashFlowForecast forecastMainBalance({
  required int startCents,
  required DateTime now,
  required Iterable<RecurringRule> recurring,
  required Iterable<AllocationRule> allocations,
  int days = 30,
}) {
  final start = _day(now);
  final end = start.add(Duration(days: days));
  final byDay = <DateTime, List<_Scheduled>>{};

  void schedule(DateTime nextDue, Cadence cadence, _Scheduled item) {
    var due = _day(nextDue);
    // Anything overdue fires as soon as the app next applies due rules,
    // which is today at the latest.
    while (due.isBefore(start)) {
      byDay.putIfAbsent(start, () => []).add(item);
      due = advanceDate(due, cadence);
    }
    while (!due.isAfter(end)) {
      byDay.putIfAbsent(due, () => []).add(item);
      due = advanceDate(due, cadence);
    }
  }

  for (final r in recurring) {
    if (!r.active || r.potId != null || r.kind == TxnKind.allocation) continue;
    final sign = r.kind == TxnKind.income ? 1 : -1;
    schedule(
      r.nextDue,
      r.cadence,
      _Scheduled(r.name, fixedCents: sign * r.amountCents),
    );
  }
  for (final a in allocations) {
    if (!a.active) continue;
    schedule(
      a.nextDue,
      a.cadence,
      _Scheduled(currentL.financeAllocationLabel, allocation: a),
    );
  }

  final daily = <int>[];
  final events = <ForecastEvent>[];
  var balance = startCents;
  for (var i = 0; i <= days; i++) {
    final day = start.add(Duration(days: i));
    final items = byDay[day] ?? const <_Scheduled>[];
    // Income lands before allocations take their share, matching how a
    // salary day plays out when the app applies everything at once.
    final ordered = [
      ...items.where((s) => s.allocation == null && s.fixedCents > 0),
      ...items.where((s) => s.allocation == null && s.fixedCents <= 0),
      ...items.where((s) => s.allocation != null),
    ];
    for (final s in ordered) {
      final a = s.allocation;
      final delta = a == null
          ? s.fixedCents
          : -allocationAmountCents(
              mode: a.mode,
              valueCents: a.valueCents,
              percentBps: a.percentBps,
              baseCents: balance,
            );
      if (delta == 0) continue;
      balance += delta;
      events.add(ForecastEvent(day, s.label, delta));
    }
    daily.add(balance);
  }
  return CashFlowForecast(start: start, dailyCents: daily, events: events);
}

class _Scheduled {
  _Scheduled(this.label, {this.fixedCents = 0, this.allocation});
  final String label;
  final int fixedCents;
  final AllocationRule? allocation;
}

// ---- Debts ------------------------------------------------------------------

/// Outstanding balance of a debt: principal minus everything paid.
int debtBalanceCents(Debt debt, Iterable<DebtPayment> payments) {
  var balance = debt.principalCents;
  for (final p in payments) {
    if (p.debtId == debt.id) balance -= p.amountCents;
  }
  return balance;
}

/// Net effect of all debts on net worth: money owed to the user counts for
/// it, money the user owes counts against it. Settled debts add nothing.
int debtsNetCents(Iterable<Debt> debts, Iterable<DebtPayment> payments) {
  var net = 0;
  for (final d in debts) {
    final balance = debtBalanceCents(d, payments);
    if (balance <= 0) continue;
    net += d.direction == DebtDirection.owe ? -balance : balance;
  }
  return net;
}

/// When a debt will be paid off at its monthly payment.
class PayoffProjection {
  const PayoffProjection({
    required this.months,
    required this.totalInterestCents,
    required this.payoffDate,
  });
  final int months;
  final int totalInterestCents;
  final DateTime payoffDate;
}

/// Month-by-month amortization of [balanceCents] at [interestBps] a year,
/// paying [monthlyPaymentCents] at the end of each month. Returns null when
/// the payment never clears the balance (it doesn't even cover the
/// interest), or when there is nothing to project.
PayoffProjection? projectPayoff({
  required int balanceCents,
  required int interestBps,
  required int monthlyPaymentCents,
  required DateTime from,
}) {
  if (balanceCents <= 0 || monthlyPaymentCents <= 0) return null;
  final monthlyRate = interestBps / 10000 / 12;
  var balance = balanceCents.toDouble();
  var interest = 0.0;
  var months = 0;
  // 100 years is well past any real loan; beyond that treat it as never.
  while (balance > 0.5 && months < 1200) {
    final accrued = balance * monthlyRate;
    if (accrued >= monthlyPaymentCents) return null;
    interest += accrued;
    balance += accrued - monthlyPaymentCents;
    months++;
  }
  if (months >= 1200) return null;
  var date = _day(from);
  for (var i = 0; i < months; i++) {
    date = advanceDate(date, Cadence.monthly);
  }
  return PayoffProjection(
    months: months,
    totalInterestCents: interest.round(),
    payoffDate: date,
  );
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
