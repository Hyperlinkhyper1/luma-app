import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../settings/settings_controller.dart';
import '../../settings/settings_scope.dart';
import '../../theme/luma_theme.dart';
import 'ai_agent_store.dart';
import 'ai_key_store.dart';
import 'providers/ai_client.dart';
import 'providers/ai_providers.dart';

/// The "AI Assistant" settings block: pick a provider and enter/replace/clear
/// its API key. Collapsed by default (see [LumaCollapsibleSection]) — this
/// is a secondary block, not a primary setting.
class AiSettingsSection extends StatelessWidget {
  const AiSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProviderPicker(settings: settings),
          const SizedBox(height: 12),
          // Re-mounts the key-management body whenever the provider changes,
          // so its per-provider loaded state (masked key, etc.) is fresh.
          _AiKeyBody(
            key: ValueKey(settings.aiProviderId),
            providerId: settings.aiProviderId,
          ),
          // Hosted agent profiles (e.g. Mistral's Agents API `agent_id`) are
          // currently only supported for the "Luma"/Mistral provider — see
          // AiProviderInfo.client.agentsBaseUrl.
          if (settings.aiProviderId == AiProviderId.mistral.name) ...[
            const SizedBox(height: 16),
            _AgentProfilesSection(
              key: ValueKey('${settings.aiProviderId}-agents'),
              providerId: settings.aiProviderId,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  const _ProviderPicker({required this.settings});
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final provider in kAiProviders)
          _ProviderChip(
            provider: provider,
            selected: provider.id.name == settings.aiProviderId,
            onTap: () => settings.setAiProviderId(provider.id.name),
            luma: luma,
          ),
      ],
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.provider,
    required this.selected,
    required this.onTap,
    required this.luma,
  });

  final AiProviderInfo provider;
  final bool selected;
  final VoidCallback onTap;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? luma.accent : luma.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(provider.icon,
                  size: 16, color: selected ? luma.accent : luma.textSecondary),
              const SizedBox(width: 8),
              Text(
                provider.displayName,
                style: TextStyle(
                  color: selected ? luma.accent : luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiKeyBody extends StatefulWidget {
  const _AiKeyBody({super.key, required this.providerId});
  final String providerId;

  @override
  State<_AiKeyBody> createState() => _AiKeyBodyState();
}

class _AiKeyBodyState extends State<_AiKeyBody> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _testing = false;
  bool _saving = false;
  String? _savedMasked;
  late final Future<void> _load = _loadSavedKey();

  AiProviderInfo get _provider => aiProviderById(widget.providerId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSavedKey() async {
    final store = await AiKeyStore.load();
    final key = await store.readKey(widget.providerId);
    if (!mounted) return;
    setState(() => _savedMasked = key == null ? null : _mask(key));
  }

  static String _mask(String key) {
    if (key.length <= 8) return '••••••••';
    return '${key.substring(0, 7)}••••${key.substring(key.length - 4)}';
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() => _saving = true);
    final store = await AiKeyStore.load();
    await store.saveKey(widget.providerId, value);
    _controller.clear();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedMasked = _mask(value);
    });
    _showSnack('API key saved.');
  }

  Future<void> _testConnection() async {
    final store = await AiKeyStore.load();
    final key = _controller.text.trim().isNotEmpty
        ? _controller.text.trim()
        : await store.readKey(widget.providerId);
    if (key == null || key.isEmpty) {
      _showSnack('Enter an API key first.');
      return;
    }
    setState(() => _testing = true);
    try {
      await _provider.client.chat(
        apiKey: key,
        history: const [AiTurn(role: 'user', text: 'Hi')],
        systemPrompt: '',
        tools: const [],
        executeTool: (_, __) async => const {},
        metadataFor: (_, __) => null,
      );
      _showSnack('Connection works.');
    } on AiError catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Could not verify the key: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _clear() async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        title: Text('Remove API key?',
            style: TextStyle(color: luma.textPrimary)),
        content: Text(
          'You won\'t be able to chat with ${_provider.displayName} until '
          'you add another key.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Remove', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final store = await AiKeyStore.load();
    await store.clearKey(widget.providerId);
    if (!mounted) return;
    setState(() => _savedMasked = null);
    _showSnack('API key removed.');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return FutureBuilder<void>(
      future: _load,
      builder: (context, _) => LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_savedMasked != null) ...[
              Row(
                children: [
                  Icon(Icons.key_rounded, size: 16, color: luma.accent),
                  const SizedBox(width: 8),
                  Text(_savedMasked!,
                      style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              obscureText: _obscure,
              style: TextStyle(color: luma.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: _savedMasked == null
                    ? _provider.keyHint
                    : 'Enter a new key to replace it',
                hintStyle: TextStyle(color: luma.textMuted),
                filled: true,
                fillColor: luma.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: luma.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: luma.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: luma.accent),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: luma.textMuted,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                LumaPrimaryButton(
                  label: 'Save',
                  icon: Icons.save_rounded,
                  loading: _saving,
                  onTap: _save,
                ),
                LumaGhostButton(
                  label: 'Test connection',
                  icon: Icons.wifi_tethering_rounded,
                  onTap: _testing ? null : _testConnection,
                ),
                if (_savedMasked != null)
                  LumaGhostButton(
                    label: 'Remove key',
                    icon: Icons.delete_outline_rounded,
                    onTap: _clear,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Stored locally on this device only, encrypted at rest. Sent '
              'directly to ${_provider.displayName} when you chat — never '
              'to any luma server.',
              style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user save several named hosted-agent IDs for Mistral's Agents
/// API and pick which one (if any) the assistant runs against — "switch
/// between multiple agent ids", per the feature request. Only rendered for
/// the Mistral/"Luma" provider.
class _AgentProfilesSection extends StatefulWidget {
  const _AgentProfilesSection({super.key, required this.providerId});
  final String providerId;

  @override
  State<_AgentProfilesSection> createState() => _AgentProfilesSectionState();
}

class _AgentProfilesSectionState extends State<_AgentProfilesSection> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  bool _adding = false;
  List<AgentProfile> _profiles = const [];
  String? _activeAgentId;
  late final Future<void> _load = _reload();

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final store = await AiAgentStore.load();
    final profiles = await store.listProfiles(widget.providerId);
    final active = await store.activeAgentId(widget.providerId);
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _activeAgentId = active;
    });
  }

  Future<void> _addProfile() async {
    final name = _nameController.text.trim();
    final agentId = _idController.text.trim();
    if (name.isEmpty || agentId.isEmpty) return;
    setState(() => _adding = true);
    final store = await AiAgentStore.load();
    await store.addProfile(widget.providerId, AgentProfile(name: name, agentId: agentId));
    await store.setActiveAgentId(widget.providerId, agentId);
    _nameController.clear();
    _idController.clear();
    if (!mounted) return;
    setState(() => _adding = false);
    await _reload();
  }

  Future<void> _selectAgent(String? agentId) async {
    final store = await AiAgentStore.load();
    await store.setActiveAgentId(widget.providerId, agentId);
    setState(() => _activeAgentId = agentId);
  }

  Future<void> _removeProfile(String agentId) async {
    final store = await AiAgentStore.load();
    await store.removeProfile(widget.providerId, agentId);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return FutureBuilder<void>(
      future: _load,
      builder: (context, _) => LumaCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 16, color: luma.accent),
                const SizedBox(width: 8),
                Text(
                  'Hosted agents',
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Optional: point the assistant at a specific agent you\'ve '
              "configured on Mistral's platform instead of the default model.",
              style: TextStyle(color: luma.textMuted, fontSize: 11.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            _AgentOptionRow(
              label: 'None — use default model',
              selected: _activeAgentId == null,
              onTap: () => _selectAgent(null),
            ),
            for (final profile in _profiles) ...[
              const SizedBox(height: 8),
              _AgentOptionRow(
                label: profile.name,
                subtitle: profile.agentId,
                selected: _activeAgentId == profile.agentId,
                onTap: () => _selectAgent(profile.agentId),
                onDelete: () => _removeProfile(profile.agentId),
              ),
            ],
            const SizedBox(height: 14),
            Divider(color: luma.border, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13),
                    decoration: _agentFieldDecoration(luma, hint: 'Name'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _idController,
                    style: TextStyle(color: luma.textPrimary, fontSize: 13),
                    decoration: _agentFieldDecoration(luma, hint: 'Agent ID'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LumaGhostButton(
              label: 'Add agent',
              icon: Icons.add_rounded,
              onTap: _adding ? null : _addProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentOptionRow extends StatelessWidget {
  const _AgentOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.onDelete,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? luma.accent : luma.border),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: selected ? luma.accent : luma.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: luma.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: luma.textMuted),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _agentFieldDecoration(LumaPalette luma, {required String hint}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: TextStyle(color: luma.textMuted),
    filled: true,
    fillColor: luma.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    enabledBorder: border(luma.border),
    focusedBorder: border(luma.accent),
  );
}
