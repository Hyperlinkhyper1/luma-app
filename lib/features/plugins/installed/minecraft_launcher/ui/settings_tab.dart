import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../logic/mc_paths.dart';

import 'hover_sync_scroll.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _loaded = false;
  List<String> _runtimeVersions = const [];

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
    if (!mounted) return;
    setState(() {
      _runtimeVersions = versions..sort();
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }

    return HoverSyncScroll(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            'Settings',
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
                  'Java runtimes',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Downloaded automatically the first time an instance needs them.',
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_runtimeVersions.isEmpty)
                  Text(
                    'None downloaded yet.',
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
        ],
      ),
    );
  }
}
