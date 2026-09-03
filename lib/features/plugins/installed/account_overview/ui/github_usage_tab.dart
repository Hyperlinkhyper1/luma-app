import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import '../account_overview_scope.dart';
import '../github_models.dart';
import 'github_connect_dialog.dart';
import 'account_shared.dart';

/// Usage and allowances: the Copilot meter, the storage meter, the Actions
/// compute meter, and the billing lines behind them.
///
/// Every meter distinguishes three states that look alike if you are
/// careless: *used nothing*, *allowance unknown*, and *could not read
/// billing at all*. Collapsing them would tell a user with a valid token and
/// a quiet month that something is broken.
class GithubUsageTab extends StatelessWidget {
  const GithubUsageTab({super.key});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repository = AccountOverviewScope.of(context);
    final billing = repository.snapshot.billing;
    final credentials = repository.credentials;

    final copilotUsed = billing.copilotQuantity;
    // The legacy per-product endpoints 404 for many personal accounts now;
    // when that leaves these at zero, fall back to the enhanced usage
    // endpoint's per-product totals rather than showing "0" next to a
    // breakdown table that clearly has activity.
    final storageUsed = billing.storageGbUsed > 0
        ? billing.storageGbUsed
        : billing.sharedStorageQuantity;
    final minutesUsed =
        billing.minutesUsed > 0 ? billing.minutesUsed : billing.actionsQuantity;

    // GitHub's own included figure wins; the user's recorded allowance is
    // the fallback, never an override.
    final minutesTotal = billing.minutesIncluded > 0
        ? billing.minutesIncluded
        : credentials?.minutesAllowance;
    final storageTotal = credentials?.storageAllowanceGb;
    final copilotTotal = credentials?.copilotAllowance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        if (!billing.available)
          AccountNotice(
            icon: Icons.lock_outline_rounded,
            message: billing.unavailableReason ??
                'Billing data is not available for this token.',
            action: AccountLinkButton(
              label: 'Reconnect',
              onTap: () => showGithubConnectDialog(context),
            ),
          )
        else if (billing.unavailableReason != null)
          AccountNotice(message: billing.unavailableReason!),
        if (!billing.available || billing.unavailableReason != null)
          const SizedBox(height: 16),
        _BillingCycleStrip(billing: billing),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final meters = [
              AccountPanel(
                title: 'GitHub Copilot',
                icon: Icons.auto_awesome_outlined,
                subtitle: 'This billing period',
                child: AccountMeter(
                  label: 'Copilot usage',
                  icon: Icons.smart_toy_outlined,
                  used: copilotUsed,
                  total: copilotTotal,
                  unit: billing.copilotUnit,
                  onSetAllowance: () => showGithubAllowanceDialog(context),
                  caption: billing.copilotSpend > 0
                      ? 'Billed beyond the included allowance: '
                          '\$${billing.copilotSpend.toStringAsFixed(2)}'
                      : 'Nothing billed beyond the included allowance.',
                ),
              ),
              AccountPanel(
                title: 'Storage',
                icon: Icons.sd_storage_outlined,
                subtitle: 'Packages and Actions artifacts',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AccountMeter(
                      label: 'Shared storage',
                      icon: Icons.folder_zip_outlined,
                      used: storageUsed,
                      total: storageTotal,
                      unit: 'GB',
                      onSetAllowance: () => showGithubAllowanceDialog(context),
                      formatter: (v) => formatDecimal(v, decimals: 2),
                    ),
                    if (billing.bandwidthGbIncluded > 0 ||
                        billing.bandwidthGbUsed > 0) ...[
                      const SizedBox(height: 20),
                      AccountMeter(
                        label: 'Packages bandwidth',
                        icon: Icons.swap_vert_rounded,
                        used: billing.bandwidthGbUsed,
                        total: billing.bandwidthGbIncluded > 0
                            ? billing.bandwidthGbIncluded
                            : null,
                        unit: 'GB',
                        formatter: (v) => formatDecimal(v, decimals: 2),
                      ),
                    ],
                  ],
                ),
              ),
              AccountPanel(
                title: 'Workflow compute',
                icon: Icons.memory_rounded,
                subtitle: 'GitHub Actions minutes',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AccountMeter(
                      label: 'Actions minutes',
                      icon: Icons.timer_outlined,
                      used: minutesUsed,
                      total: minutesTotal,
                      unit: 'minutes',
                      onSetAllowance: () => showGithubAllowanceDialog(context),
                      caption: billing.paidMinutesUsed > 0
                          ? '${formatDecimal(billing.paidMinutesUsed)} minutes '
                              'billed beyond the allowance.'
                          : null,
                    ),
                    if (billing.minutesBreakdown.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _RunnerBreakdown(breakdown: billing.minutesBreakdown),
                    ],
                  ],
                ),
              ),
            ];

            if (constraints.maxWidth < 900) {
              return Column(
                children: [
                  for (final meter in meters) ...[
                    meter,
                    const SizedBox(height: 16),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < meters.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: meters[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _UsageBreakdown(billing: billing),
        const SizedBox(height: 16),
        Center(
          child: AccountLinkButton(
            label: 'Adjust your allowances',
            icon: Icons.tune_rounded,
            onTap: () => showGithubAllowanceDialog(context),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'GitHub reports consumption but not always the allowance that '
              'goes with it. Meters without a bar are waiting on a figure '
              'from your billing page.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: luma.textMuted, fontSize: 11, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _BillingCycleStrip extends StatelessWidget {
  const _BillingCycleStrip({required this.billing});

  final GithubBilling billing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 200).floor().clamp(2, 3);
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final tiles = [
          AccountStatTile(
            icon: Icons.event_available_outlined,
            label: 'Days left in cycle',
            value: billing.daysLeftInCycle > 0
                ? formatCount(billing.daysLeftInCycle)
                : '—',
            caption: 'until the meters reset',
          ),
          AccountStatTile(
            icon: Icons.receipt_long_outlined,
            label: 'Billed this period',
            value: '\$${billing.totalSpend.toStringAsFixed(2)}',
            caption: 'beyond included allowances',
            tint: billing.totalSpend > 0 ? luma.warning : luma.success,
          ),
          AccountStatTile(
            icon: Icons.list_alt_rounded,
            label: 'Usage lines',
            value: formatCount(billing.usageItems.length),
            caption: 'products with activity',
          ),
        ];
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

/// Minutes per runner OS. Windows and macOS minutes are billed at a
/// multiple of Linux ones, which is exactly why the split is worth showing.
class _RunnerBreakdown extends StatelessWidget {
  const _RunnerBreakdown({required this.breakdown});

  final Map<String, double> breakdown;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'By runner',
          style: TextStyle(
            color: luma.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    _prettyRunner(entry.key),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: luma.textSecondary, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Stack(
                      children: [
                        Container(height: 6, color: luma.surfaceHover),
                        LayoutBuilder(
                          builder: (context, constraints) => Container(
                            height: 6,
                            width: constraints.maxWidth *
                                (max <= 0 ? 0 : entry.value / max),
                            color: luma.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 58,
                  child: Text(
                    formatMinutes(entry.value),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 11.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// `UBUNTU_4_CORE` reads badly in a 74px column; `Ubuntu 4 core` does not.
  static String _prettyRunner(String key) {
    final words = key.toLowerCase().split('_');
    return [
      for (final word in words)
        word.isEmpty
            ? word
            : word == 'macos'
                ? 'macOS'
                : '${word[0].toUpperCase()}${word.substring(1)}',
    ].join(' ');
  }
}

/// The raw billing lines, so a surprising meter can be traced to the product
/// and repository that caused it.
class _UsageBreakdown extends StatelessWidget {
  const _UsageBreakdown({required this.billing});

  final GithubBilling billing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (billing.usageItems.isEmpty) {
      return AccountPanel(
        title: 'Usage breakdown',
        icon: Icons.table_rows_outlined,
        child: Text(
          billing.available
              ? 'No billable usage reported for this period.'
              : 'Connect a token that can read billing to see the breakdown.',
          style: TextStyle(color: luma.textMuted, fontSize: 12),
        ),
      );
    }

    // One row per product rather than per day: a month of Copilot lines is
    // noise, the per-product total is the number people came for.
    final byProduct = <String, ({double quantity, double amount, String unit})>{};
    for (final item in billing.usageItems) {
      final existing = byProduct[item.product];
      byProduct[item.product] = (
        quantity: (existing?.quantity ?? 0) + item.quantity,
        amount: (existing?.amount ?? 0) + item.netAmount,
        unit: item.unitType.isNotEmpty
            ? item.unitType
            : (existing?.unit ?? ''),
      );
    }
    final rows = byProduct.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));

    return AccountPanel(
      title: 'Usage breakdown',
      icon: Icons.table_rows_outlined,
      subtitle: 'Totalled by product for this billing period',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: luma.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Product',
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Quantity',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Billed',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: luma.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: luma.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      rows[i].key,
                      maxLines: 2,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${formatDecimal(rows[i].value.quantity, decimals: 2)}'
                      '${rows[i].value.unit.isEmpty ? '' : ' ${rows[i].value.unit}'}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 12,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '\$${rows[i].value.amount.toStringAsFixed(2)}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: rows[i].value.amount > 0
                            ? luma.textPrimary
                            : luma.textMuted,
                        fontSize: 12,
                        fontWeight: rows[i].value.amount > 0
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontFeatures: const [FontFeature.tabularFigures()],
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
