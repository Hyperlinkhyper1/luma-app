import 'package:flutter/material.dart';

import '../app/widgets.dart';
import '../l10n/app_localizations.dart';
import '../theme/luma_theme.dart';
import 'pet_repository.dart';
import 'pet_scope.dart';
import 'pet_sprite.dart';

/// Settings for the luma pet: whether Alt+Space summons it, what it is
/// called, and a button to call it up from here — which is also the only way
/// in when the hotkey could not be registered.
class PetSettingsSection extends StatefulWidget {
  const PetSettingsSection({super.key});

  @override
  State<PetSettingsSection> createState() => _PetSettingsSectionState();
}

class _PetSettingsSectionState extends State<PetSettingsSection> {
  final TextEditingController _name = TextEditingController();
  bool _primed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final pet = PetScope.of(context);
    // Seeded once the saved pet has actually loaded, so the field doesn't
    // start on the default name and then jump.
    if (!_primed && pet.loaded) {
      _primed = true;
      _name.text = pet.name;
    }

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PetSprite(
                mood: pet.mood,
                patCount: pet.pats,
                size: 56,
                animate: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.petSettingsTitle,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.petSettingsSubtitle,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (PetRepository.supportsGlobalHotKey)
            // A plain row rather than a SwitchListTile: a ListTile inside the
            // card's own decorated box paints its ink splash underneath it.
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.petSettingsHotkey,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: pet.enabled,
                  onChanged: pet.setEnabled,
                  activeThumbColor: luma.onAccent,
                  activeTrackColor: luma.accent,
                  inactiveThumbColor: luma.textSecondary,
                  inactiveTrackColor: luma.surfaceHover,
                ),
              ],
            ),
          if (pet.enabled && pet.hotKeyError != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: luma.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.petSettingsHotkeyTaken,
                    style: TextStyle(
                      color: luma.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  onSubmitted: pet.setName,
                  onTapOutside: (_) => pet.setName(_name.text),
                  style: TextStyle(color: luma.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: t.petSettingsName,
                    labelStyle: TextStyle(color: luma.textSecondary),
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: luma.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: luma.accent, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              LumaGhostButton(
                label: t.petSettingsSummon,
                icon: Icons.auto_awesome_rounded,
                onTap: pet.open,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
