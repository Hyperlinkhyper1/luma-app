import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../logic/curseforge_api_client.dart';
import '../logic/mc_paths.dart';

import 'curseforge_key_dialog.dart';
import 'hover_sync_scroll.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _loaded = false;
  List<String> _runtimeVersions = const [];
  bool _hasCurseForgeKey = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final runtimesDir = await McPaths.runtimes();
    final versions = <String>[];
    if (await runtimesDir.exists()) {
      await for (final entity in runtimesDir.list()) {
        if (entity is Directory) {
          versions.add(entity.path.split(Platform.pathSeparator).last);
        }
      }
    }
    final hasKey = await CurseForgeApiClient.instance.hasKey();
    if (!mounted) return;
    setState(() {
      _hasCurseForgeKey = hasKey;
      _runtimeVersions = versions..sort();
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }

    return HoverSyncScroll(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            t.commonSettings,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          LumaCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.mcLauncherJavaRuntimes,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.mcLauncherRuntimesHint,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_runtimeVersions.isEmpty)
                  Text(
                    t.mcLauncherNoRuntimes,
                    style: TextStyle(color: luma.textMuted, fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in _runtimeVersions)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: luma.accentSubtle,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Java $v',
                            style: TextStyle(
                              color: luma.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _curseForgeCard(luma),
        ],
      ),
    );
  }

  Future<void> _editCurseForgeKey() async {
    if (await showCurseForgeKeyDialog(context)) {
      setState(() => _hasCurseForgeKey = true);
    }
  }

  Future<void> _removeCurseForgeKey() async {
    await CurseForgeApiClient.instance.saveKey('');
    if (mounted) setState(() => _hasCurseForgeKey = false);
  }

  Widget _curseForgeCard(LumaPalette luma) {
    final t = L.of(context);
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CurseForge',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _hasCurseForgeKey
                ? t.mcLauncherCurseForgeKeySaved
                : t.mcLauncherCurseForgeKeyAdd,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LumaPrimaryButton(
                label: _hasCurseForgeKey ? t.mcLauncherChangeApiKey : t.mcLauncherAddApiKey,
                icon: Icons.key_rounded,
                onTap: _editCurseForgeKey,
              ),
              if (_hasCurseForgeKey)
                LumaGhostButton(
                  label: t.mcLauncherRemoveKey,
                  icon: Icons.delete_outline_rounded,
                  onTap: _removeCurseForgeKey,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
