import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../finance_scope.dart';
import '../logic/finance_logic.dart';
import '../logic/money.dart';
import 'lookups.dart';
import 'pot_detail_page.dart';

const _potColors = <int>[
  0xFF7C5AD9, 0xFF4CAF50, 0xFF2196F3, 0xFFFF9800,
  0xFFE91E63, 0xFF009688, 0xFFFFC107, 0xFF9C27B0,
  0xFF00BCD4, 0xFFF44336, 0xFF3F51B5, 0xFF607D8B,
];

final _potIcons = <int>[
  Icons.savings_rounded.codePoint,
  Icons.home_rounded.codePoint,
  Icons.flight_takeoff_rounded.codePoint,
  Icons.directions_car_rounded.codePoint,
  Icons.school_rounded.codePoint,
  Icons.favorite_rounded.codePoint,
  Icons.shopping_bag_rounded.codePoint,
  Icons.restaurant_rounded.codePoint,
  Icons.fitness_center_rounded.codePoint,
  Icons.pets_rounded.codePoint,
  Icons.card_giftcard_rounded.codePoint,
  Icons.beach_access_rounded.codePoint,
  Icons.phone_android_rounded.codePoint,
  Icons.computer_rounded.codePoint,
];

class PotsTab extends StatelessWidget {
  const PotsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = FinanceScope.of(context);
    return StreamData<List<Category>>(
      stream: repo.watchCategories(),
      builder: (context, categories) => StreamData<List<Merchant>>(
        stream: repo.watchMerchants(),
        builder: (context, merchants) => StreamData<List<Pot>>(
          stream: repo.watchPots(),
          builder: (context, pots) => StreamData<List<FinanceTransaction>>(
            stream: repo.watchTransactions(),
            builder: (context, txns) {
              final balances = computeBalances(txns);
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Available to allocate: ${formatCents(balances.mainCents)}',
                          style: TextStyle(
                              color: context.luma.textSecondary, fontSize: 13),
                        ),
                        const Spacer(),
                        LumaPrimaryButton(
                          label: 'New pot',
                          icon: Icons.add_rounded,
                          onTap: () => _openEditor(context, repo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: pots.isEmpty
                          ? LumaEmptyState(
                              icon: Icons.savings_rounded,
                              title: 'No pots yet',
                              subtitle:
                                  'Create pots like "Rent", "Groceries" or "Holiday" to divide your money.',
                            )
                          : ListView(
                              children: [
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  children: [
                                    for (final pot in pots)
                                      _PotCard(
                                        pot: pot,
                                        balanceCents: balances.balanceForPot(pot.id),
                                        repo: repo,
                                        allTxns: txns,
                                        categories: categories,
                                        merchants: merchants,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                    ),
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

class _PotCard extends StatelessWidget {
  const _PotCard({
    required this.pot,
    required this.balanceCents,
    required this.repo,
    required this.allTxns,
    required this.categories,
    required this.merchants,
  });
  final Pot pot;
  final int balanceCents;
  final FinanceRepository repo;
  final List<FinanceTransaction> allTxns;
  final List<Category> categories;
  final List<Merchant> merchants;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showPotDetail(
          context,
          pot: pot,
          allTxns: allTxns,
          categories: categories,
          merchants: merchants,
        ),
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: luma.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LumaIconBadge(
                    icon: materialIcon(pot.iconCodepoint),
                    color: Color(pot.colorValue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pot.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        size: 18, color: luma.textMuted),
                    color: luma.surface,
                    onSelected: (v) {
                      switch (v) {
                        case 'add':
                          _openAddMoney(context, repo, pot);
                        case 'edit':
                          _openEditor(context, repo, pot: pot);
                        case 'delete':
                          _confirmDelete(context, repo, pot);
                      }
                    },
                    itemBuilder: (context) => [
                      _menuItem('add', Icons.add_rounded, 'Add money', luma),
                      _menuItem('edit', Icons.edit_rounded, 'Edit', luma),
                      _menuItem('delete', Icons.delete_outline_rounded, 'Delete',
                          luma,
                          danger: true),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Balance',
                  style: TextStyle(color: luma.textMuted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                formatCents(balanceCents),
                style: TextStyle(
                  color: balanceCents < 0 ? luma.danger : luma.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

PopupMenuItem<String> _menuItem(
    String value, IconData icon, String label, LumaPalette luma,
    {bool danger = false}) {
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: danger ? luma.danger : luma.textSecondary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: luma.textPrimary)),
      ],
    ),
  );
}

Future<void> _confirmDelete(
    BuildContext context, FinanceRepository repo, Pot pot) async {
  final luma = context.luma;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: luma.surface,
      title: Text('Delete "${pot.name}"?',
          style: TextStyle(color: luma.textPrimary)),
      content: Text(
        'Entries assigned to this pot will move back to your main balance.',
        style: TextStyle(color: luma.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Delete', style: TextStyle(color: luma.danger)),
        ),
      ],
    ),
  );
  if (ok == true) await repo.deletePot(pot.id);
}

Future<void> _openAddMoney(
    BuildContext context, FinanceRepository repo, Pot pot) {
  final controller = TextEditingController();
  final luma = context.luma;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: luma.surface,
      title: Text('Add money to "${pot.name}"',
          style: TextStyle(color: luma.textPrimary, fontSize: 17)),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: luma.textPrimary),
        decoration: InputDecoration(
          prefixText: '€ ',
          prefixStyle: TextStyle(color: luma.textSecondary),
          hintText: '0,00',
          hintStyle: TextStyle(color: luma.textMuted),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: () async {
            final cents = parseToCents(controller.text);
            if (cents != null && cents > 0) {
              await repo.allocateToPot(pot.id, cents);
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: Text('Add', style: TextStyle(color: luma.accent)),
        ),
      ],
    ),
  );
}

Future<void> _openEditor(BuildContext context, FinanceRepository repo,
    {Pot? pot}) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: context.luma.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: _PotEditor(repo: repo, pot: pot),
      ),
    ),
  );
}

class _PotEditor extends StatefulWidget {
  const _PotEditor({required this.repo, this.pot});
  final FinanceRepository repo;
  final Pot? pot;

  @override
  State<_PotEditor> createState() => _PotEditorState();
}

class _PotEditorState extends State<_PotEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.pot?.name ?? '');
  late int _color = widget.pot?.colorValue ?? _potColors.first;
  late int _icon = widget.pot?.iconCodepoint ?? _potIcons.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (widget.pot == null) {
      await widget.repo.createPot(
        name: name,
        colorValue: _color,
        iconCodepoint: _icon,
      );
    } else {
      await widget.repo.updatePot(
        widget.pot!.copyWith(name: name, colorValue: _color, iconCodepoint: _icon),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.pot == null ? 'New pot' : 'Edit pot',
              style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            style: TextStyle(color: luma.textPrimary),
            decoration: InputDecoration(
              hintText: 'Pot name (e.g. Holiday)',
              hintStyle: TextStyle(color: luma.textMuted),
              filled: true,
              fillColor: luma.background,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: luma.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: luma.accent),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Color', style: TextStyle(color: luma.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in _potColors)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c ? luma.textPrimary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Icon', style: TextStyle(color: luma.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final ic in _potIcons)
                GestureDetector(
                  onTap: () => setState(() => _icon = ic),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _icon == ic ? luma.accentSubtle : luma.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _icon == ic ? luma.accent : luma.border,
                      ),
                    ),
                    child: Icon(materialIcon(ic),
                        size: 20,
                        color: _icon == ic ? luma.accent : luma.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LumaGhostButton(
                label: 'Cancel',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: widget.pot == null ? 'Create' : 'Save',
                icon: Icons.check_rounded,
                onTap: _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
