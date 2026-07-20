import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../logic/launcher_settings_store.dart';
import '../logic/mc_paths.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _clientIdController = TextEditingController();
  bool _loaded = false;
  List<String> _runtimeVersions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final clientId = await LauncherSettingsStore.getMicrosoftClientId();
    final runtimesDir = await McPaths.runtimes();
    final versions = <String>[];
    if (await runtimesDir.exists()) {
      await for (final entity in runtimesDir.list()) {
        if (entity is Directory) versions.add(entity.path.split(Platform.pathSeparator).last);
      }
    }
    if (!mounted) return;
    setState(() {
      _clientIdController.text = clientId ?? '';
      _runtimeVersions = versions..sort();
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (!_loaded) return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Text(
          'Settings',
          style: TextStyle(color: luma.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Microsoft sign-in',
                style: TextStyle(color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Your own Azure AD application (client) ID, used for online-mode sign-in.',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientIdController,
                decoration: const InputDecoration(labelText: 'Application (client) ID'),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: LumaGhostButton(
                  label: 'Save',
                  icon: Icons.save_outlined,
                  onTap: () async {
                    await LauncherSettingsStore.setMicrosoftClientId(_clientIdController.text.trim());
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Saved.')));
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LumaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Java runtimes',
                style: TextStyle(color: luma.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Downloaded automatically the first time an instance needs them.',
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (_runtimeVersions.isEmpty)
                Text('None downloaded yet.', style: TextStyle(color: luma.textMuted, fontSize: 13))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in _runtimeVersions)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: luma.accentSubtle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Java $v',
                            style: TextStyle(color: luma.accent, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
