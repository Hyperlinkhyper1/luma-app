import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../theme/luma_theme.dart';
import '../steam_price_history.dart' show formatSteamPrice;

/// Estimates a CS2 seller's Steam Wallet proceeds from the buyer-facing price.
/// Steam calculates the two fees separately and each has a one-cent minimum.
class Cs2SellingCalculatorTab extends StatefulWidget {
  const Cs2SellingCalculatorTab({super.key});

  @override
  State<Cs2SellingCalculatorTab> createState() =>
      _Cs2SellingCalculatorTabState();
}

class _Cs2SellingCalculatorTabState extends State<Cs2SellingCalculatorTab> {
  final _controller = TextEditingController();
  String _currency = 'USD';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final buyerPays = _parseCents(_controller.text);
    final result = buyerPays == null || buyerPays <= 0
        ? null
        : estimateCs2MarketPayout(buyerPays);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CS2 Selling Calculator',
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'See your estimated Steam Wallet proceeds after the market fees.',
                style: TextStyle(color: luma.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: luma.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Buyer pays',
                        hintText: '0.00',
                        prefixText: _currencySymbol(_currency),
                        filled: true,
                        fillColor: luma.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: luma.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: InputDecoration(
                        labelText: 'Currency',
                        filled: true,
                        fillColor: luma.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                      ],
                      onChanged: (value) =>
                          setState(() => _currency = value ?? 'USD'),
                    ),
                  ),
                ],
              ),
              if (result case final payout?) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: luma.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: luma.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You receive',
                        style: TextStyle(color: luma.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatSteamPrice(payout.sellerReceivesCents, _currency),
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FeeRow(
                        label: 'Steam fee (5%)',
                        value: payout.steamFeeCents,
                        currency: _currency,
                      ),
                      const SizedBox(height: 7),
                      _FeeRow(
                        label: 'CS2 fee (10%)',
                        value: payout.gameFeeCents,
                        currency: _currency,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Estimate only. Fees are calculated separately and rounded down to cents, with a minimum of one cent each. Steam may handle other currencies differently.',
                style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class Cs2MarketPayout {
  const Cs2MarketPayout({
    required this.sellerReceivesCents,
    required this.steamFeeCents,
    required this.gameFeeCents,
  });

  final int sellerReceivesCents;
  final int steamFeeCents;
  final int gameFeeCents;
}

/// Reverse-calculates the greatest cent-valued seller amount whose total
/// (seller amount plus both fees) does not exceed [buyerPaysCents].
Cs2MarketPayout estimateCs2MarketPayout(int buyerPaysCents) {
  var seller = (buyerPaysCents / 1.15).floor();
  while (seller > 0) {
    final steamFee = _fee(seller, 5);
    final gameFee = _fee(seller, 10);
    if (seller + steamFee + gameFee <= buyerPaysCents) {
      return Cs2MarketPayout(
        sellerReceivesCents: seller,
        steamFeeCents: steamFee,
        gameFeeCents: gameFee,
      );
    }
    seller--;
  }
  return const Cs2MarketPayout(
    sellerReceivesCents: 0,
    steamFeeCents: 0,
    gameFeeCents: 0,
  );
}

int _fee(int sellerCents, int percent) {
  final fee = sellerCents * percent ~/ 100;
  return fee < 1 ? 1 : fee;
}

int? _parseCents(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  final amount = double.tryParse(normalized);
  if (amount == null || !amount.isFinite || amount <= 0) return null;
  return (amount * 100).round();
}

String _currencySymbol(String currency) => switch (currency) {
  'EUR' => '€ ',
  'GBP' => '£ ',
  _ => r'$ ',
};

class _FeeRow extends StatelessWidget {
  const _FeeRow({required this.label, required this.value, required this.currency});

  final String label;
  final int value;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 12))),
        Text(formatSteamPrice(value, currency), style: TextStyle(color: luma.textPrimary, fontSize: 12)),
      ],
    );
  }
}
