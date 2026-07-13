import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import '../app/pin_dialog.dart';

import '../app/update/app_version.dart';
import '../app/update/update_gate.dart';
import '../app/widgets.dart';
import '../features/chat/ai_settings_section.dart';
import '../l10n/app_localizations.dart';
import '../theme/luma_theme.dart';
import 'settings_controller.dart';
import 'settings_scope.dart';

/// The Settings destination: appearance (theme + accent), behavior and an
/// about section. Reads and mutates the app-wide [SettingsController].
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final luma = context.luma;
    final t = L.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Appearance --------------------------------------------
              _SectionHeader(
                icon: Icons.palette_rounded,
                title: t.settingsAppearance,
                subtitle: t.settingsAppearanceSub,
              ),
              const SizedBox(height: 12),
              LumaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RowLabel(t.settingsTheme),
                    const SizedBox(height: 10),
                    LumaSegmentedTabs(
                      tabs: [
                        t.settingsSystem,
                        t.settingsLight,
                        t.settingsDark,
                      ],
                      selectedIndex: _themeIndex(settings.themeMode),
                      onSelect: (i) =>
                          settings.setThemeMode(_themeModeFor(i)),
                    ),
                    Divider(color: luma.border, height: 32),
                    _RowLabel(t.settingsAccentColor),
                    const SizedBox(height: 14),
                    _AccentPicker(settings: settings),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ---- General -----------------------------------------------
              _SectionHeader(
                icon: Icons.tune_rounded,
                title: t.settingsGeneral,
                subtitle: t.settingsGeneralSub,
              ),
              const SizedBox(height: 12),
              LumaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RowLabel(t.settingsLanguage),
                    const SizedBox(height: 10),
                    _LanguageDropdown(settings: settings, t: t),
                    Divider(color: luma.border, height: 32),
                    _RowLabel(t.settingsOpenOnLaunch),
                    const SizedBox(height: 10),
                    LumaSegmentedTabs(
                      tabs: [
                        t.navHome,
                        t.navFileConverter,
                        t.navFinance,
                      ],
                      selectedIndex: settings.startScreen.index,
                      onSelect: (i) => settings
                          .setStartScreen(StartScreen.values[i]),
                    ),
                    Divider(color: luma.border, height: 32),
                    _ToggleRow(
                      title: t.settingsHideAmounts,
                      subtitle: t.settingsHideAmountsSub,
                      value: settings.hideAmounts,
                      onChanged: settings.setHideAmounts,
                    ),
                    Divider(color: luma.border, height: 32),
                    _ToggleRow(
                      title: t.settingsLockPasswords,
                      subtitle: t.settingsLockPasswordsSub,
                      value: settings.lockPasswordHash != null,
                      onChanged: (enabled) =>
                          _toggleLockPassword(context, settings, enabled),
                    ),
                    Divider(color: luma.border, height: 32),
                    _ToggleRow(
                      title: t.settingsAmericanGpa,
                      subtitle: t.settingsAmericanGpaSub,
                      value: settings.useAmericanGpaScale,
                      onChanged: settings.setUseAmericanGpaScale,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ---- AI Assistant (collapsible) -----------------------------
              LumaCollapsibleSection(
                icon: Icons.smart_toy_rounded,
                title: t.settingsAiAssistant,
                subtitle: t.settingsAiAssistantSub,
                child: const AiSettingsSection(),
              ),

              const SizedBox(height: 24),

              // ---- About -------------------------------------------------
              _SectionHeader(
                icon: Icons.info_outline_rounded,
                title: t.settingsAbout,
                subtitle: null,
              ),
              const SizedBox(height: 12),
              const _AboutCard(),

              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: LumaGhostButton(
                  label: t.settingsResetDefaults,
                  icon: Icons.restart_alt_rounded,
                  onTap: () => _confirmReset(context, settings),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _toggleLockPassword(
      BuildContext context, SettingsController settings, bool enable) async {
    final t = L.of(context);
    if (enable) {
      final pin1 = await showPinDialog(context, title: t.pinEnterNew);
      if (pin1 == null) return;
      if (!context.mounted) return;
      final pin2 = await showPinDialog(context, title: t.pinVerify);
      if (pin2 == null) return;
      if (pin1 != pin2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.pinNotMatch)),
          );
        }
        return;
      }
      final hash = sha256.convert(utf8.encode(pin1)).toString();
      settings.setLockPasswordHash(hash);
    } else {
      final pin = await showPinDialog(context, title: t.pinEnterDisable);
      if (pin == null) return;
      final hash = sha256.convert(utf8.encode(pin)).toString();
      if (hash == settings.lockPasswordHash) {
        settings.setLockPasswordHash(null);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.pinIncorrect)),
          );
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
        title: Text(t.settingsResetTitle,
            style: TextStyle(color: luma.textPrimary)),
        content: Text(
          t.settingsResetContent,
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.settingsResetCancel,
                style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              settings.resetToDefaults();
              Navigator.of(context).pop();
            },
            child: Text(t.settingsResetConfirm,
                style: TextStyle(color: luma.accent)),
          ),
        ],
      ),
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.settings});
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (var i = 0; i < kAccentPresets.length; i++)
          _Swatch(
            // The default preset (null seed) renders with the live accent.
            color: kAccentPresets[i].seed ?? luma.accent,
            label: kAccentPresets[i].name,
            selected: settings.accentIndex == i,
            onTap: () => settings.setAccentIndex(i),
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: luma.surfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AppLanguage>(
          value: settings.appLanguage,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded, color: luma.textSecondary),
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: luma.surface,
          items: [
            for (final e in entries)
              DropdownMenuItem(
                value: e.$1,
                child: Text(e.$2),
              ),
          ],
          onChanged: (v) {
            if (v != null) settings.setAppLanguage(v);
          },
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? luma.textPrimary : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: selected ? 12 : 0,
                ),
              ],
            ),
            child: selected
                ? Icon(Icons.check_rounded,
                    size: 20,
                    color: color.computeLuminance() > 0.55
                        ? const Color(0xFF1A1526)
                        : Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(color: luma.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: luma.onAccent,
          activeTrackColor: luma.accent,
          inactiveThumbColor: luma.textSecondary,
          inactiveTrackColor: luma.surfaceHover,
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
    return LumaCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [luma.accentHover, luma.accent],
              ),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: luma.onAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('luma',
                    style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(versionLabel,
                    style:
                        TextStyle(color: luma.textMuted, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                checkAndPromptForUpdate(context, announceIfUpToDate: true),
            child: Text(t.settingsCheckUpdates),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Icon(icon, size: 18, color: luma.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(color: luma.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: context.luma.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );
}

int _themeIndex(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 0,
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
    };

ThemeMode _themeModeFor(int index) => switch (index) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };
