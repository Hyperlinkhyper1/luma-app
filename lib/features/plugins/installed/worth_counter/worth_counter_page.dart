import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../storage/storage_guard.dart';
import '../../../../theme/luma_theme.dart';
import 'worth_counter_store.dart';

/// Accent colors offered when adding a product, so rows stay easy to tell
/// apart at a glance while counting.
const _productColors = <int>[
  0xFF7C5AD9,
  0xFF2F80ED,
  0xFF00B8A9,
  0xFF12A372,
  0xFFF5A623,
  0xFFE5484D,
  0xFFF25F9C,
  0xFF5D6470,
];

/// The Worth Counter plugin: add products with a set money value, tally them
/// up with + and -, and see what the whole count is worth at the bottom.
class WorthCounterPage extends StatefulWidget {
  const WorthCounterPage({super.key});

  @override
  State<WorthCounterPage> createState() => _WorthCounterPageState();
}

class _WorthCounterPageState extends State<WorthCounterPage> {
  final _store = WorthCounterStore();

  @override
  void dispose() {
    _store.flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;

    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final products = _store.products;
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showProductEditor(context, _store),
            backgroundColor: luma.accent,
            foregroundColor: luma.onAccent,
            tooltip: 'Add product',
            child: const Icon(Icons.add_rounded, size: 28),
          ),
          bottomNavigationBar: _TotalBar(
            total: _store.grandTotal,
            itemCount: _store.totalCount,
            onResetAll: products.isEmpty ? null : () => _confirmResetAll(context),
          ),
          body: !_store.loaded
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              : SingleChildScrollView(
                  // Extra bottom padding so the last row clears the button.
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: products.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 64),
                              child: LumaEmptyState(
                                icon: Icons.calculate_rounded,
                                title: 'No products yet',
                                subtitle:
                                    'Add a product with what one is worth, then '
                                    'count them up with + and -. The total '
                                    'value shows at the bottom.',
                                action: LumaPrimaryButton(
                                  label: 'Add product',
                                  icon: Icons.add_rounded,
                                  onTap: () =>
                                      _showProductEditor(context, _store),
                                ),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < products.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 12),
                                  _ProductRow(
                                    product: products[i],
                                    onIncrement: () =>
                                        _store.increment(products[i].id),
                                    onDecrement: () =>
                                        _store.decrement(products[i].id),
                                    onEdit: () => _showProductEditor(
                                      context,
                                      _store,
                                      existing: products[i],
                                    ),
                                    onResetCount: () =>
                                        _store.resetCount(products[i].id),
                                    onDelete: () =>
                                        _confirmDelete(context, products[i]),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WorthProduct product) async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text(
          'Delete product?',
          style: TextStyle(color: luma.textPrimary, fontSize: 16),
        ),
        content: Text(
          'This removes "${product.name}" and its count from the tally.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.delete(product.id);
    }
  }

  Future<void> _confirmResetAll(BuildContext context) async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text(
          'Reset every count?',
          style: TextStyle(color: luma.textPrimary, fontSize: 16),
        ),
        content: Text(
          'All products stay in the list, but their counts go back to zero.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Reset', style: TextStyle(color: luma.accent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _store.resetAllCounts();
    }
  }
}

/// One counted product: its worth per unit, the -/+ stepper, and what the
/// current count of it adds up to.
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onResetCount,
    required this.onDelete,
  });

  final WorthProduct product;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onResetCount;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Below this the stepper and the line total no longer fit next to the
        // name, so they move onto a second line (phones, narrow windows).
        final compact = constraints.maxWidth < 460;
        return LumaCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: compact ? _buildCompact(context) : _buildWide(context),
        );
      },
    );
  }

  Widget _buildWide(BuildContext context) {
    return Row(
      children: [
        _avatar(),
        const SizedBox(width: 14),
        Expanded(child: _titleBlock(context)),
        const SizedBox(width: 8),
        _stepper(context),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 84),
          child: _lineTotal(context, align: TextAlign.right),
        ),
        _menu(context),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _avatar(),
            const SizedBox(width: 14),
            Expanded(child: _titleBlock(context)),
            _menu(context),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _lineTotal(context, align: TextAlign.left),
            const Spacer(),
            _stepper(context),
            const SizedBox(width: 6),
          ],
        ),
      ],
    );
  }

  Widget _avatar() {
    final color = Color(product.color);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        product.name.isEmpty ? '?' : product.name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _titleBlock(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '€${product.price.toStringAsFixed(2)} each',
          style: TextStyle(color: luma.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _stepper(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          tooltip: 'One less',
          enabled: product.count > 0,
          onTap: onDecrement,
        ),
        SizedBox(
          width: 52,
          child: Text(
            '${product.count}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          tooltip: 'One more',
          filled: true,
          onTap: onIncrement,
        ),
      ],
    );
  }

  Widget _lineTotal(BuildContext context, {required TextAlign align}) {
    final luma = context.luma;
    return Text(
      '€${product.total.toStringAsFixed(2)}',
      textAlign: align,
      style: TextStyle(
        color: product.count == 0 ? luma.textMuted : luma.textPrimary,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final luma = context.luma;
    return PopupMenuButton<String>(
      tooltip: 'More',
      color: luma.surface,
      icon: Icon(Icons.more_vert_rounded, color: luma.textMuted, size: 20),
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'reset') {
          onResetCount();
        } else {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Text('Edit product',
              style: TextStyle(color: luma.textPrimary, fontSize: 13.5)),
        ),
        PopupMenuItem(
          value: 'reset',
          child: Text('Reset count',
              style: TextStyle(color: luma.textPrimary, fontSize: 13.5)),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete',
              style: TextStyle(color: luma.danger, fontSize: 13.5)),
        ),
      ],
    );
  }
}

/// The square - / + button either side of a product's count.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final background = filled ? luma.accent : luma.background;
    final foreground = filled ? luma.onAccent : luma.textPrimary;

    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onTap : null,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: filled ? null : Border.all(color: luma.border),
              ),
              child: Icon(icon, size: 20, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pinned bar along the bottom with the sum of everything counted.
class _TotalBar extends StatelessWidget {
  const _TotalBar({
    required this.total,
    required this.itemCount,
    required this.onResetAll,
  });

  final double total;
  final int itemCount;
  final VoidCallback? onResetAll;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(top: BorderSide(color: luma.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On narrow windows the labelled reset button collapses to an icon
          // so the amount itself never gets squeezed.
          final compact = constraints.maxWidth < 420;
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      itemCount == 1
                          ? '1 item counted'
                          : '$itemCount items counted',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (onResetAll != null) ...[
                if (compact)
                  IconButton(
                    onPressed: onResetAll,
                    tooltip: 'Reset all counts',
                    icon: Icon(Icons.restart_alt_rounded,
                        color: luma.textSecondary, size: 20),
                  )
                else ...[
                  LumaGhostButton(
                    label: 'Reset all',
                    icon: Icons.restart_alt_rounded,
                    onTap: onResetAll,
                  ),
                  const SizedBox(width: 16),
                ],
              ],
              Text(
                '€${total.toStringAsFixed(2)}',
                maxLines: 1,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---- Product editor --------------------------------------------------------

void _showProductEditor(
  BuildContext context,
  WorthCounterStore store, {
  WorthProduct? existing,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _ProductEditorDialog(store: store, existing: existing),
  );
}

class _ProductEditorDialog extends StatefulWidget {
  const _ProductEditorDialog({required this.store, this.existing});

  final WorthCounterStore store;
  final WorthProduct? existing;

  @override
  State<_ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<_ProductEditorDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _price = TextEditingController(
    text: widget.existing == null
        ? ''
        : widget.existing!.price.toStringAsFixed(2),
  );
  late int _color = widget.existing?.color ?? _productColors.first;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Accepts both `2.50` and `2,50` — a comma decimal is the norm in euros.
  double? _parsePrice() {
    final raw = _price.text.trim().replaceAll('€', '').replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null || value < 0) return null;
    return value;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = _parsePrice();
    if (name.isEmpty) {
      setState(() => _error = 'Give the product a name.');
      return;
    }
    if (price == null) {
      setState(() => _error = 'Enter what one is worth, e.g. 2.50.');
      return;
    }
    final existing = widget.existing;
    if (existing == null) {
      try {
        await widget.store.add(name: name, price: price, color: _color);
      } on StorageLimitExceededException catch (e) {
        if (mounted) setState(() => _error = '$e');
        return;
      }
    } else {
      widget.store.edit(existing.id, name: name, price: price, color: _color);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AlertDialog(
      backgroundColor: luma.surface,
      title: Text(
        widget.existing == null ? 'Add product' : 'Edit product',
        style: TextStyle(color: luma.textPrimary, fontSize: 16),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(luma, 'Name'),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              autofocus: true,
              style: TextStyle(color: luma.textPrimary),
              decoration: _dec(luma, hint: 'e.g. Coffee'),
            ),
            const SizedBox(height: 14),
            _label(luma, 'Worth per item (€)'),
            const SizedBox(height: 6),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: TextStyle(color: luma.textPrimary),
              decoration: _dec(luma, hint: 'e.g. 2.00'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 14),
            _label(luma, 'Color'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in _productColors)
                  GestureDetector(
                    onTap: () => setState(() => _color = value),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(value),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: _color == value
                              ? luma.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: luma.danger, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            widget.existing == null ? 'Add' : 'Save',
            style: TextStyle(color: luma.accent),
          ),
        ),
      ],
    );
  }
}

Widget _label(LumaPalette luma, String text) => Text(
      text,
      style: TextStyle(
        color: luma.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );

InputDecoration _dec(LumaPalette luma, {String? hint}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}
