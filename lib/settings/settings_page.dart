import '../security/password_hash.dart';
import 'package:flutter/material.dart';

import '../app/pin_dialog.dart';
import '../app/luma_license_page.dart';

import '../account/plan.dart';
import '../account/plan_selection_page.dart';
import '../app/update/app_version.dart';
import '../app/update/update_gate.dart';
import '../features/chat/ai_settings_section.dart';
import '../l10n/app_localizations.dart';
import '../pet/pet_settings_section.dart';
import '../theme/autumn_ornaments.dart';
import '../theme/coffee_ornaments.dart';
import '../theme/luma_theme.dart';
import '../theme/theme_style.dart';
import 'settings_controller.dart';
import 'settings_scope.dart';

/// The Settings destination: appearance (theme + accent), behavior and an
/// about section. Reads and mutates the app-wide [SettingsController].
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.onEditHome});

  final VoidCallback? onEditHome;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

enum _SettingsCategory { appearance, general, assistant, pet, about }

class _SettingsPageState extends State<SettingsPage> {
  _SettingsCategory _selected = _SettingsCategory.appearance;
  final Set<_SettingsCategory> _visited = {_SettingsCategory.appearance};

  void _select(_SettingsCategory category) {
    if (_selected == category) return;
    setState(() {
      _selected = category;
      _visited.add(category);
    });
  }

  String _title(_SettingsCategory category, L t) => switch (category) {
    _SettingsCategory.appearance => t.settingsAppearance,
    _SettingsCategory.general => t.settingsGeneral,
    _SettingsCategory.assistant => t.settingsAiAssistant,
    _SettingsCategory.pet => t.petSettingsTitle,
    _SettingsCategory.about => t.settingsAbout,
  };

  IconData _icon(_SettingsCategory category) => switch (category) {
    _SettingsCategory.appearance => Icons.palette_outlined,
    _SettingsCategory.general => Icons.tune_rounded,
    _SettingsCategory.assistant => Icons.smart_toy_outlined,
    _SettingsCategory.pet => Icons.auto_awesome_outlined,
    _SettingsCategory.about => Icons.info_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final luma = context.luma;
    final t = L.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final content = Expanded(
          child: Stack(
            children: [
              for (final category in _visited)
                Positioned.fill(
                  key: ValueKey('settings-panel-${category.name}'),
                  child: Offstage(
                    offstage: category != _selected,
                    child: TickerMode(
                      enabled: category == _selected,
                      child: SingleChildScrollView(
                        primary: false,
                        key: PageStorageKey('settings-scroll-${category.name}'),
                        padding: EdgeInsets.fromLTRB(
                          wide ? 44 : 20,
                          wide ? 38 : 24,
                          wide ? 44 : 20,
                          40,
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 960),
                            child: Column(
                              key: ValueKey(
                                'settings-content-${category.name}',
                              ),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _PageHeading(
                                  title: _title(category, t),
                                  subtitle: switch (category) {
                                    _SettingsCategory.appearance =>
                                      t.settingsAppearanceSub,
                                    _SettingsCategory.general =>
                                      t.settingsGeneralSub,
                                    _SettingsCategory.assistant =>
                                      t.settingsAiAssistantSub,
                                    _SettingsCategory.pet =>
                                      t.petSettingsSubtitle,
                                    _SettingsCategory.about => null,
                                  },
                                ),
                                const SizedBox(height: 30),
                                ..._body(category, settings, t),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(
                  color: luma.surface.withValues(alpha: 0.65),
                  border: Border(bottom: BorderSide(color: luma.border)),
                ),
                child: _DropdownFrame(
                  child: DropdownButton<_SettingsCategory>(
                    key: const ValueKey('settings-category-picker'),
                    value: _selected,
                    isExpanded: true,
                    dropdownColor: luma.surface,
                    borderRadius: BorderRadius.circular(12),
                    icon: Icon(
                      Icons.expand_more_rounded,
                      color: luma.textSecondary,
                    ),
                    items: [
                      for (final category in _SettingsCategory.values)
                        DropdownMenuItem(
                          value: category,
                          child: Row(
                            children: [
                              Icon(
                                _icon(category),
                                size: 19,
                                color: luma.accent,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_title(category, t))),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) _select(value);
                    },
                  ),
                ),
              ),
              content,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 236,
              decoration: BoxDecoration(
                color: luma.surface.withValues(alpha: 0.45),
                border: Border(right: BorderSide(color: luma.border)),
              ),
              child: SingleChildScrollView(
                primary: false,
                padding: const EdgeInsets.fromLTRB(18, 38, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 28),
                      child: Text(
                        t.navSettings,
                        style: context.lumaDecor.applyDisplayFont(
                          TextStyle(
                            color: luma.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    for (final category in _SettingsCategory.values) ...[
                      _CategoryButton(
                        key: ValueKey('settings-nav-${category.name}'),
                        title: _title(category, t),
                        icon: _icon(category),
                        selected: category == _selected,
                        onTap: () => _select(category),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
              ),
            ),
            content,
          ],
        );
      },
    );
  }

  List<Widget> _body(
    _SettingsCategory category,
    SettingsController settings,
    L t,
  ) {
    final luma = context.luma;
    return switch (category) {
      _SettingsCategory.appearance => [
        _SettingSection(
          title: t.settingsTheme,
          child: _ThemeModePicker(settings: settings, t: t),
        ),
        _SettingSection(
          title: t.settingsThemeStyle,
          child: _ThemeStylePicker(settings: settings, t: t),
        ),
        _SettingSection(
          title: t.settingsAccentColor,
          child: _AccentPicker(settings: settings, t: t),
        ),
        const SizedBox(height: 4),
        _HomeScreenCallout(onEditHome: widget.onEditHome),
      ],
      _SettingsCategory.general => [
        _SettingsPanel(
          child: Column(
            children: [
              _FormRow(
                icon: Icons.language_rounded,
                title: t.settingsLanguage,
                control: _LanguageDropdown(settings: settings, t: t),
              ),
              Divider(color: luma.border, height: 40),
              _FormRow(
                icon: Icons.open_in_browser_rounded,
                title: t.settingsOpenOnLaunch,
                control: _DropdownFrame(
                  child: DropdownButton<StartScreen>(
                    key: const ValueKey('settings-start-screen'),
                    value: settings.startScreen,
                    isExpanded: true,
                    dropdownColor: luma.surface,
                    icon: Icon(
                      Icons.expand_more_rounded,
                      color: luma.textSecondary,
                    ),
                    items: [
                      for (final screen in StartScreen.values)
                        DropdownMenuItem(
                          value: screen,
                          child: Text(
                            [
                              t.navHome,
                              t.navFileConverter,
                              t.navFinance,
                            ][screen.index],
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) settings.setStartScreen(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SettingsPanel(
          child: Column(
            children: [
              _ToggleRow(
                controlKey: const ValueKey('settings-hide-amounts'),
                icon: Icons.visibility_off_outlined,
                title: t.settingsHideAmounts,
                subtitle: t.settingsHideAmountsSub,
                value: settings.hideAmounts,
                onChanged: settings.setHideAmounts,
              ),
              Divider(color: luma.border, height: 36),
              _ToggleRow(
                controlKey: const ValueKey('settings-lock-passwords'),
                icon: Icons.lock_outline_rounded,
                title: t.settingsLockPasswords,
                subtitle: t.settingsLockPasswordsSub,
                value: settings.lockPasswordHash != null,
                onChanged: (enabled) =>
                    _toggleLockPassword(context, settings, enabled),
              ),
              Divider(color: luma.border, height: 36),
              _ToggleRow(
                controlKey: const ValueKey('settings-american-gpa'),
                icon: Icons.school_outlined,
                title: t.settingsAmericanGpa,
                subtitle: t.settingsAmericanGpaSub,
                value: settings.useAmericanGpaScale,
                onChanged: settings.setUseAmericanGpaScale,
              ),
            ],
          ),
        ),
      ],
      _SettingsCategory.assistant => [const AiSettingsSection()],
      _SettingsCategory.pet => [const PetSettingsSection()],
      _SettingsCategory.about => [
        const _AboutCard(),
        const SizedBox(height: 20),
        _SettingsPanel(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('settings-licenses'),
              icon: const Icon(Icons.description_outlined, size: 19),
              label: Text(t.settingsOpenSourceLicenses),
              style: TextButton.styleFrom(
                textStyle: _settingsButtonTextStyle(context),
              ),
              onPressed: () => showLumaLicensePage(
                context: context,
                applicationName: 'luma',
                applicationVersion: AppVersion.isReleaseBuild
                    ? AppVersion.current
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Divider(color: luma.border, height: 1),
        const SizedBox(height: 24),
        _FormRow(
          icon: Icons.restart_alt_rounded,
          title: t.settingsResetDefaults,
          subtitle: t.settingsResetContent,
          control: OutlinedButton.icon(
            key: const ValueKey('settings-reset'),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text(t.settingsResetDefaults),
            style: OutlinedButton.styleFrom(
              textStyle: _settingsButtonTextStyle(context),
              foregroundColor: luma.danger,
              side: BorderSide(color: luma.danger.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onPressed: () => _confirmReset(context, settings),
          ),
        ),
      ],
    };
  }

  static Future<void> _toggleLockPassword(
    BuildContext context,
    SettingsController settings,
    bool enable,
  ) async {
    final t = L.of(context);
    if (enable) {
      final pin1 = await showPinDialog(context, title: t.pinEnterNew);
      if (pin1 == null) return;
      if (!context.mounted) return;
      final pin2 = await showPinDialog(context, title: t.pinVerify);
      if (pin2 == null) return;
      if (pin1 != pin2) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.pinNotMatch)));
        }
        return;
      }
      final hash = await PasswordHash.create(pin1);
      settings.setLockPasswordHash(hash);
    } else {
      final pin = await showPinDialog(context, title: t.pinEnterDisable);
      if (pin == null) return;
      if (await PasswordHash.verify(pin, settings.lockPasswordHash!)) {
        settings.setLockPasswordHash(null);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.pinIncorrect)));
        }
      }
    }
  }

  static void _confirmReset(BuildContext context, SettingsController settings) {
    final luma = context.luma;
    final t = L.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text(
          t.settingsResetTitle,
          style: TextStyle(color: luma.textPrimary),
        ),
        content: Text(
          t.settingsResetContent,
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              t.settingsResetCancel,
              style: TextStyle(color: luma.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              settings.resetToDefaults();
              Navigator.of(context).pop();
            },
            child: Text(
              t.settingsResetConfirm,
              style: TextStyle(color: luma.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// The theme styles side by side, each showing a swatch of its own
/// palette so the choice is visible before it's made. A style the plan
/// doesn't cover stays visible but locked, with the upgrade route one tap
/// away — hiding it would leave the user wondering what they're missing.
class _ThemeStylePicker extends StatelessWidget {
  const _ThemeStylePicker({required this.settings, required this.t});
  final SettingsController settings;
  final L t;

  String _name(LumaThemeStyle style) => switch (style) {
    LumaThemeStyle.standard => t.settingsThemeStyleDefault,
    LumaThemeStyle.coffee => t.settingsThemeStyleCoffee,
    LumaThemeStyle.autumn => t.settingsThemeStyleAutumn,
  };

  String _blurb(LumaThemeStyle style) => switch (style) {
    LumaThemeStyle.standard => t.settingsThemeStyleDefaultSub,
    LumaThemeStyle.coffee => t.settingsThemeStyleCoffeeSub,
    LumaThemeStyle.autumn => t.settingsThemeStyleAutumnSub,
  };

  void _onTap(BuildContext context, LumaThemeStyle style) {
    if (settings.canUseThemeStyle(style)) {
      settings.setThemeStyle(style);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          style == LumaThemeStyle.autumn
              ? t.settingsThemeStyleUpgradeAutumn
              : t.settingsThemeStyleUpgrade,
        ),
        action: SnackBarAction(
          label: planById('orbit').name,
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PlanSelectionPage())),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // All across when there's room, stacked on a phone.
        final across = constraints.maxWidth >= 640;
        final cards = [
          for (final option in kThemeStyles)
            _ThemeStyleCard(
              option: option,
              name: _name(option.style),
              blurb: _blurb(option.style),
              lockedLabel: t.settingsThemeStyleLocked,
              // The user's pick stays highlighted even while locked, so a
              // lapsed plan reads as "paused", not "reset".
              selected: settings.preferredThemeStyle == option.style,
              locked: !settings.canUseThemeStyle(option.style),
              onTap: () => _onTap(context, option.style),
            ),
        ];
        if (!across) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                cards[i],
              ],
            ],
          );
        }
        // IntrinsicHeight gives the Row a bounded height so the cards can
        // stretch to match each other. Without it the Row inherits the
        // scroll view's unbounded height and the layout throws.
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: cards[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ThemeStyleCard extends StatefulWidget {
  const _ThemeStyleCard({
    required this.option,
    required this.name,
    required this.blurb,
    required this.lockedLabel,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final ThemeStyleOption option;
  final String name;
  final String blurb;
  final String lockedLabel;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  State<_ThemeStyleCard> createState() => _ThemeStyleCardState();
}

class _ThemeStyleCardState extends State<_ThemeStyleCard> {
  /// The dark palette of the style being offered — the preview shows what
  /// you'd get, not what you currently have.
  LumaPalette get _preview =>
      LumaPalette.forStyle(widget.option.style, Brightness.dark);

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final selected = widget.selected;

    final shape = decor.cardShape(
      side: BorderSide(
        color: selected ? luma.accent : luma.border,
        width: selected ? 1.5 : decor.borderWidth,
      ),
    );
    return Semantics(
      selected: selected,
      label: widget.locked ? widget.lockedLabel : null,
      child: Material(
        color: selected ? luma.accentSubtle : luma.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('theme-style-${widget.option.style.name}'),
          customBorder: shape,
          onTap: widget.onTap,
          hoverColor: luma.accent.withValues(alpha: 0.06),
          focusColor: luma.accent.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniWindowPreview(
                  palette: _preview,
                  style: widget.option.style,
                  height: 90,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      // Each name is set in its own style's display face,
                      // so the typeface is part of the preview.
                      child: Text(
                        widget.name,
                        style: LumaDecor.forStyle(widget.option.style)
                            .applyDisplayFont(
                              TextStyle(
                                color: luma.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                      ),
                    ),
                    if (widget.locked)
                      Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: luma.textSecondary,
                      )
                    else if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: luma.accent,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.blurb,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                if (widget.locked) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: luma.accentSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.lockedLabel,
                      style: TextStyle(
                        color: luma.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniWindowPreview extends StatelessWidget {
  const _MiniWindowPreview({
    required this.palette,
    this.style = LumaThemeStyle.standard,
    this.height = 80,
  });

  final LumaPalette palette;
  final LumaThemeStyle style;
  final double height;

  @override
  Widget build(BuildContext context) {
    final decor = LumaDecor.forStyle(style);
    return ExcludeSemantics(
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: palette.background,
          shape: decor.cardShape(side: BorderSide(color: palette.border)),
        ),
        child: Column(
          children: [
            Container(
              height: 15,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              color: palette.surface,
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 3),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 34,
                    color: palette.rail,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 9,
                    ),
                    child: Column(
                      children: [
                        Container(height: 5, color: palette.accent),
                        const SizedBox(height: 7),
                        Container(height: 3, color: palette.border),
                        const SizedBox(height: 5),
                        Container(height: 3, color: palette.border),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: 0.6,
                                  child: Container(
                                    height: 5,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: ShapeDecoration(
                                      color: palette.surface,
                                      shape: decor.cardShape(),
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: FractionallySizedBox(
                                        widthFactor: 0.6,
                                        child: Container(
                                          height: 4,
                                          color: palette.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (style != LumaThemeStyle.standard) ...[
                            const SizedBox(width: 10),
                            if (style == LumaThemeStyle.coffee)
                              CoffeeBeanIcon(color: palette.accent, size: 24)
                            else
                              MapleLeafIcon(color: palette.accent, size: 26),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({required this.settings, required this.t});
  final SettingsController settings;
  final L t;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return LayoutBuilder(
      builder: (context, constraints) {
        final across = constraints.maxWidth >= 480;
        final cards = [
          for (final mode in ThemeMode.values)
            Builder(
              builder: (context) {
                final selected = settings.themeMode == mode;
                final label = switch (mode) {
                  ThemeMode.system => t.settingsSystem,
                  ThemeMode.light => t.settingsLight,
                  ThemeMode.dark => t.settingsDark,
                };
                final shape = context.lumaDecor.cardShape(
                  side: BorderSide(
                    color: selected ? luma.accent : luma.border,
                    width: selected ? 1.5 : 1,
                  ),
                );
                final preview = SizedBox(
                  width: across ? double.infinity : 112,
                  child: mode == ThemeMode.system
                      ? ClipRect(
                          child: Stack(
                            children: [
                              const _MiniWindowPreview(
                                palette: LumaPalette.light,
                              ),
                              Positioned.fill(
                                child: ClipRect(
                                  clipper: const _RightHalfClipper(),
                                  child: const _MiniWindowPreview(
                                    palette: LumaPalette.dark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _MiniWindowPreview(
                          palette: mode == ThemeMode.dark
                              ? LumaPalette.dark
                              : LumaPalette.light,
                        ),
                );
                final labelRow = Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? luma.accent : luma.textSecondary,
                      size: 19,
                    ),
                  ],
                );
                return Semantics(
                  selected: selected,
                  child: Material(
                    color: selected ? luma.accentSubtle : luma.surface,
                    shape: shape,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('theme-mode-${mode.name}'),
                      customBorder: shape,
                      onTap: () => settings.setThemeMode(mode),
                      focusColor: luma.accent.withValues(alpha: 0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: across
                            ? Column(
                                children: [
                                  preview,
                                  const SizedBox(height: 14),
                                  labelRow,
                                ],
                              )
                            : Row(
                                children: [
                                  preview,
                                  const SizedBox(width: 16),
                                  Expanded(child: labelRow),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ];
        return across
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: cards[i]),
                  ],
                ],
              )
            : Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    cards[i],
                  ],
                ],
              );
      },
    );
  }
}

class _RightHalfClipper extends CustomClipper<Rect> {
  const _RightHalfClipper();
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height);
  @override
  bool shouldReclip(_RightHalfClipper oldClipper) => false;
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.settings, required this.t});
  final SettingsController settings;
  final L t;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // Coffee and Autumn ship complete palettes, so re-hueing would undo the look
    // the user just chose. Say so rather than silently doing nothing.
    final paused = settings.themeStyle != LumaThemeStyle.standard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: paused ? 0.4 : 1,
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (var i = 0; i < kAccentPresets.length; i++)
                _Swatch(
                  key: ValueKey('accent-$i'),
                  // The default preset (null seed) renders with the live
                  // accent.
                  color: kAccentPresets[i].seed ?? luma.accent,
                  label: kAccentPresets[i].label(t),
                  selected: settings.accentIndex == i,
                  onTap: paused ? null : () => settings.setAccentIndex(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          kAccentPresets[settings.accentIndex].label(t),
          style: TextStyle(
            color: luma.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (paused) ...[
          const SizedBox(height: 10),
          Text(
            settings.themeStyle == LumaThemeStyle.autumn
                ? t.settingsAccentAutumnNote
                : t.settingsAccentCoffeeNote,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  const _LanguageDropdown({required this.settings, required this.t});
  final SettingsController settings;
  final L t;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final entries = [
      (AppLanguage.system, t.langSystemDefault),
      (AppLanguage.english, t.langEnglish),
      (AppLanguage.dutch, t.langDutch),
      (AppLanguage.chinese, t.langChinese),
      (AppLanguage.spanish, t.langSpanish),
      (AppLanguage.french, t.langFrench),
    ];
    return _DropdownFrame(
      child: DropdownButton<AppLanguage>(
        key: const ValueKey('settings-language'),
        value: settings.appLanguage,
        isExpanded: true,
        icon: Icon(Icons.expand_more_rounded, color: luma.textSecondary),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: luma.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        dropdownColor: luma.surface,
        items: [
          for (final e in entries)
            DropdownMenuItem(value: e.$1, child: Text(e.$2)),
        ],
        onChanged: (v) {
          if (v != null) settings.setAppLanguage(v);
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        selected: selected,
        enabled: onTap != null,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? luma.textPrimary : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: color.computeLuminance() > 0.55
                          ? const Color(0xFF1A1526)
                          : Colors.white,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.controlKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final Key controlKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: luma.textSecondary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: title,
          child: Switch(
            key: controlKey,
            value: value,
            onChanged: onChanged,
            activeThumbColor: luma.onAccent,
            activeTrackColor: luma.accent,
            inactiveThumbColor: luma.textSecondary,
            inactiveTrackColor: luma.surfaceHover,
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final versionLabel = AppVersion.isReleaseBuild
        ? t.aboutVersionRelease(AppVersion.current)
        : t.aboutVersionDev;
    return _SettingsPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: luma.accentSubtle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: luma.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'luma',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      versionLabel,
                      style: TextStyle(color: luma.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          );
          final action = OutlinedButton.icon(
            key: const ValueKey('settings-check-updates'),
            onPressed: () =>
                checkAndPromptForUpdate(context, announceIfUpToDate: true),
            icon: const Icon(Icons.system_update_alt_rounded, size: 18),
            label: Text(t.settingsCheckUpdates),
            style: OutlinedButton.styleFrom(
              textStyle: _settingsButtonTextStyle(context),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          );
          if (constraints.maxWidth < 540 ||
              MediaQuery.textScalerOf(context).scale(14) > 20) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [identity, const SizedBox(height: 24), action],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 24),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.lumaDecor.applyDisplayFont(
            TextStyle(
              color: luma.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: TextStyle(
              color: luma.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final shape = context.lumaDecor.cardShape();
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? luma.accentSubtle : Colors.transparent,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          focusColor: luma.accent.withValues(alpha: 0.18),
          hoverColor: luma.surfaceHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? luma.accent : luma.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: selected ? luma.accent : luma.textSecondary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingSection extends StatelessWidget {
  const _SettingSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.luma.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: ShapeDecoration(
      color: context.luma.surface,
      shape: context.lumaDecor.cardShape(
        side: BorderSide(color: context.luma.border),
      ),
    ),
    child: child,
  );
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.control,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final label = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: luma.textSecondary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: luma.textSecondary,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [label, const SizedBox(height: 16), control],
          );
        }
        return Row(
          children: [
            Expanded(child: label),
            const SizedBox(width: 32),
            SizedBox(width: 280, child: control),
          ],
        );
      },
    );
  }
}

class _DropdownFrame extends StatelessWidget {
  const _DropdownFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    decoration: ShapeDecoration(
      color: context.luma.background,
      shape: context.lumaDecor.cardShape(
        side: BorderSide(color: context.luma.border),
      ),
    ),
    child: DefaultTextStyle(
      style: TextStyle(
        color: context.luma.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      child: DropdownButtonHideUnderline(child: child),
    ),
  );
}

class _HomeScreenCallout extends StatelessWidget {
  const _HomeScreenCallout({required this.onEditHome});
  final VoidCallback? onEditHome;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return _SettingsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: ShapeDecoration(
                  color: luma.accentSubtle,
                  shape: context.lumaDecor.cardShape(),
                ),
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  size: 20,
                  color: luma.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.settingsHomeScreenTitle,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.settingsHomeScreenSub,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const ValueKey('settings-home-edit'),
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: Text(t.settingsHomeScreenEdit),
            style: OutlinedButton.styleFrom(
              textStyle: _settingsButtonTextStyle(context),
            ),
            onPressed: onEditHome,
          ),
        ],
      ),
    );
  }
}

TextStyle _settingsButtonTextStyle(BuildContext context) =>
    context.lumaDecor.labelStyle(
      Theme.of(context).textTheme.labelLarge!.copyWith(inherit: false),
    );
