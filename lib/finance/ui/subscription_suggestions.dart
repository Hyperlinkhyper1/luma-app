import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../logic/insights.dart';
import '../logic/money.dart';
import 'finance_form.dart';

/// Repeating charges found in the ledger that aren't tracked yet, each with
/// a one-click "Track as bill". Renders nothing when there are none.
class SubscriptionSuggestions extends StatelessWidget {
  const SubscriptionSuggestions({
    super.key,
    required this.repo,
    required this.rules,
  });

  final FinanceRepository repo;
  final List<RecurringRule> rules;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FinanceTransaction>>(
      stream: repo.watchTransactions(),
      builder: (context, txns) => StreamBuilder<List<Merchant>>(
        stream: repo.watchMerchants(),
        builder: (context, merchants) => StreamBuilder<Set<String>>(
          stream: repo.watchDismissedSubscriptions(),
          builder: (context, dismissed) {
            if (!txns.hasData || !merchants.hasData || !dismissed.hasData) {
              return const SizedBox.shrink();
            }
            final found = detectSubscriptions(
              txns: txns.data!,
              rules: rules,
              merchantNames: {for (final m in merchants.data!) m.id: m.name},
              now: DateTime.now(),
              dismissed: dismissed.data!,
            );
            if (found.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _SuggestionsCard(repo: repo, found: found),
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionsCard extends StatelessWidget {
  const _SuggestionsCard({required this.repo, required this.found});
  final FinanceRepository repo;
  final List<SubscriptionCandidate> found;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final monthly = found.fold<int>(
      0,
      (sum, c) =>
          sum +
          (c.cadence == Cadence.monthly
              ? c.amountCents
              : (c.amountCents * 52 / 12).round()),
    );
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.manage_search_rounded, size: 18, color: luma.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.financeSubsPossibleCount(found.length),
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                t.financeSubsMonthlyEstimate(formatCents(monthly)),
                style: TextStyle(color: luma.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            t.financeSubsExplainer,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final c in found) _SuggestionRow(repo: repo, candidate: c),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.repo, required this.candidate});
  final FinanceRepository repo;
  final SubscriptionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final c = candidate;
    final t = L.of(context);
    final cadence = c.cadence == Cadence.monthly
        ? t.financeSubsCadenceMonthly
        : t.financeSubsCadenceWeekly;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t.financeSubsRowDetail(
                    cadence,
                    formatCents(c.amountCents),
                    '${c.occurrences}',
                    shortDate(c.lastDate),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.financeSubsNotSubscription,
            icon: Icon(Icons.close_rounded, size: 18, color: luma.textMuted),
            onPressed: () => repo.dismissSubscription(c.key),
          ),
          TextButton(
            onPressed: () async {
              await repo.trackSubscription(c);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t.financeSubsTrackedSnack(
                        c.name,
                        shortDate(c.nextDue),
                      ),
                    ),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: luma.accent),
            child: Text(t.financeSubsTrackAsBill),
          ),
        ],
      ),
    );
  }
}
