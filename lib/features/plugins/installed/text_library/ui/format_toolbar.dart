import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../text_library_models.dart';
import 'rich_text_controller.dart';

/// Bold / italic / underline / strikethrough toggles and the ink palette for
/// a [RichTextController].
class FormatToolbar extends StatelessWidget {
  const FormatToolbar({super.key, required this.controller});

  final RichTextController controller;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final style = controller.activeStyle;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FormatButton(
              icon: Icons.format_bold_rounded,
              tooltip: t.textLibraryBold,
              active: style.bold,
              onTap: controller.toggleBold,
            ),
            _FormatButton(
              icon: Icons.format_italic_rounded,
              tooltip: t.textLibraryItalic,
              active: style.italic,
              onTap: controller.toggleItalic,
            ),
            _FormatButton(
              icon: Icons.format_underlined_rounded,
              tooltip: t.textLibraryUnderline,
              active: style.underline,
              onTap: controller.toggleUnderline,
            ),
            _FormatButton(
              icon: Icons.format_strikethrough_rounded,
              tooltip: t.textLibraryStrike,
              active: style.strike,
              onTap: controller.toggleStrike,
            ),
            _InkButton(color: style.color, onPick: controller.setColor),
            _FormatButton(
              icon: Icons.format_clear_rounded,
              tooltip: t.textLibraryClearFormatting,
              active: false,
              onTap: controller.clearFormatting,
            ),
          ],
        );
      },
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: active,
        label: tooltip,
        child: Material(
          color: active ? luma.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            // Keeps the caret and selection in the editor while formatting.
            canRequestFocus: false,
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                icon,
                size: 20,
                color: active ? luma.accent : luma.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InkButton extends StatelessWidget {
  const _InkButton({required this.color, required this.onPick});

  final McColor? color;
  final ValueChanged<McColor?> onPick;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return Tooltip(
      message: t.textLibraryInk,
      child: MenuAnchor(
        style: MenuStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
          backgroundColor: WidgetStatePropertyAll(luma.surface),
        ),
        menuChildren: [
          SizedBox(
            width: 4 * 40 + 3 * 6,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ink in McColor.values)
                  _Swatch(
                    color: ink.color,
                    selected: ink == color,
                    label: ink.id.replaceAll('_', ' '),
                    onTap: () => onPick(ink),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          MenuItemButton(
            leadingIcon: const Icon(Icons.format_color_reset_rounded, size: 18),
            onPressed: () => onPick(null),
            child: Text(t.textLibraryDefaultInk),
          ),
        ],
        builder: (context, menu, _) => Semantics(
          button: true,
          label: t.textLibraryInk,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            canRequestFocus: false,
            onTap: () => menu.isOpen ? menu.close() : menu.open(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.format_color_text_rounded,
                    size: 20,
                    color: luma.textSecondary,
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 20,
                    height: 4,
                    decoration: BoxDecoration(
                      color: color?.color ?? luma.textPrimary,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: luma.border, width: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          canRequestFocus: false,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? luma.accent : luma.border,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of the sixteen dye colours, for a subject's banner or a book cover.
class DyePicker extends StatelessWidget {
  const DyePicker({super.key, required this.value, required this.onChanged});

  final DyeColor value;
  final ValueChanged<DyeColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final dye in DyeColor.values)
          _Swatch(
            color: dye.color,
            selected: dye == value,
            label: dye.name,
            onTap: () => onChanged(dye),
          ),
      ],
    );
  }
}
