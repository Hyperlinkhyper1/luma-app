import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/luma_theme.dart';
import '../data/database.dart';
import '../finance_repository.dart';
import '../finance_scope.dart';
import '../logic/finance_logic.dart';
import '../logic/money.dart';
import '../logic/planning.dart';
import 'finance_form.dart';
import 'lookups.dart';
import 'planning_cards.dart';
import 'pot_detail_page.dart';

const _potColors = <int>[
  0xFF7C5AD9,
  0xFF4CAF50,
  0xFF2196F3,
  0xFFFF9800,
  0xFFE91E63,
  0xFF009688,
  0xFFFFC107,
  0xFF9C27B0,
  0xFF00BCD4,
  0xFFF44336,
  0xFF3F51B5,
  0xFF607D8B,
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
              final t = L.of(context);
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          t.financePotsAvailableToAllocate(
                            formatCents(balances.mainCents),
                          ),
                          style: TextStyle(
                            color: context.luma.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        LumaPrimaryButton(
                          label: t.financePotsNewPot,
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
                              title: t.financePotsEmptyTitle,
                              subtitle: t.financePotsEmptySubtitle,
                            )
                          : ListView(
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) => Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    children: [
                                      for (final pot in pots)
                                        SizedBox(
                                          width: constraints.maxWidth < 260
                                              ? constraints.maxWidth
                                              : 260,
                                          child: _PotCard(
                                            pot: pot,
                                            balanceCents: balances
                                                .balanceForPot(pot.id),
                                            repo: repo,
                                            allTxns: txns,
                                            categories: categories,
                                            merchants: merchants,
                                          ),
                                        ),
                                    ],
                                  ),
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
    final t = L.of(context);
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
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: luma.textMuted,
                    ),
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
                      _menuItem(
                        'add',
                        Icons.add_rounded,
                        t.financePotsAddMoney,
                        luma,
                      ),
                      _menuItem('edit', Icons.edit_rounded, t.commonEdit, luma),
                      _menuItem(
                        'delete',
                        Icons.delete_outline_rounded,
                        t.commonDelete,
                        luma,
                        danger: true,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                t.financePotsBalance,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                formatCents(balanceCents),
                style: TextStyle(
                  color: balanceCents < 0 ? luma.danger : luma.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (goalProgress(pot, balanceCents, DateTime.now())
                  case final goal?) ...[
                const SizedBox(height: 12),
                PotGoalBar(
                  progress: goal,
                  color: Color(pot.colorValue),
                  now: DateTime.now(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

PopupMenuItem<String> _menuItem(
  String value,
  IconData icon,
  String label,
  LumaPalette luma, {
  bool danger = false,
}) {
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
  BuildContext context,
  FinanceRepository repo,
  Pot pot,
) async {
  final luma = context.luma;
  final t = L.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: luma.surface,
      title: Text(
        t.financePotsDeleteTitle(pot.name),
        style: TextStyle(color: luma.textPrimary),
      ),
      content: Text(
        t.financePotsDeleteBody,
        style: TextStyle(color: luma.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            t.commonCancel,
            style: TextStyle(color: luma.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(t.commonDelete, style: TextStyle(color: luma.danger)),
        ),
      ],
    ),
  );
  if (ok == true) await repo.deletePot(pot.id);
}

Future<void> _openAddMoney(
  BuildContext context,
  FinanceRepository repo,
  Pot pot,
) {
  final controller = TextEditingController();
  final luma = context.luma;
  final t = L.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: luma.surface,
      title: Text(
        t.financePotsAddMoneyTitle(pot.name),
        style: TextStyle(color: luma.textPrimary, fontSize: 17),
      ),
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
          child: Text(
            t.commonCancel,
            style: TextStyle(color: luma.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () async {
            final cents = parseToCents(controller.text);
            if (cents != null && cents > 0) {
              await repo.allocateToPot(pot.id, cents);
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: Text(t.commonAdd, style: TextStyle(color: luma.accent)),
        ),
      ],
    ),
  );
}

Future<void> _openEditor(
  BuildContext context,
  FinanceRepository repo, {
  Pot? pot,
}) {
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
  late final TextEditingController _name = TextEditingController(
    text: widget.pot?.name ?? '',
  );
  late int _color = widget.pot?.colorValue ?? _potColors.first;
  late int _icon = widget.pot?.iconCodepoint ?? _potIcons.first;
  late final TextEditingController _goal = TextEditingController(
    text: widget.pot?.goalCents == null
        ? ''
        : (widget.pot!.goalCents! / 100)
              .toStringAsFixed(2)
              .replaceAll('.', ','),
  );
  late DateTime? _goalDate = widget.pot?.goalDate;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final goalText = _goal.text.trim();
    final goal = goalText.isEmpty ? null : parseToCents(goalText);
    if (goalText.isNotEmpty && (goal == null || goal <= 0)) {
      setState(() => _error = L.of(context).financePotsGoalNotPositive);
      return;
    }
    final int potId;
    if (widget.pot == null) {
      potId = await widget.repo.createPot(
        name: name,
        colorValue: _color,
        iconCodepoint: _icon,
      );
    } else {
      potId = widget.pot!.id;
      await widget.repo.updatePot(
        widget.pot!.copyWith(
          name: name,
          colorValue: _color,
          iconCodepoint: _icon,
        ),
      );
    }
    await widget.repo.setPotGoal(potId, goalCents: goal, goalDate: _goalDate);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.pot == null ? t.financePotsNewPot : t.financePotsEditPot,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            style: TextStyle(color: luma.textPrimary),
            decoration: InputDecoration(
              hintText: t.financePotsNameHint,
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
          Text(
            t.financePotsColor,
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
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
                        color: _color == c
                            ? luma.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            t.financePotsIcon,
            style: TextStyle(color: luma.textSecondary, fontSize: 12),
          ),
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
                    child: Icon(
                      materialIcon(ic),
                      size: 20,
                      color: _icon == ic ? luma.accent : luma.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FinanceField(
                  label: t.financePotsSavingsGoal,
                  controller: _goal,
                  hint: t.financePotsNoGoal,
                  prefix: '€ ',
                  number: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FinanceDateField(
                  label: t.financePotsReachBy,
                  date: _goalDate,
                  placeholder: t.financePotsAnyTime,
                  onChanged: (d) => setState(() => _goalDate = d),
                  onClear: () => setState(() => _goalDate = null),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: luma.danger, fontSize: 13)),
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LumaGhostButton(
                label: t.commonCancel,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: widget.pot == null ? t.commonCreate : t.commonSave,
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
