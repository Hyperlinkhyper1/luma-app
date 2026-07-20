import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../logic/fabric_installer.dart';
import '../logic/forge_installer.dart';
import '../logic/neoforge_installer.dart';
import '../logic/piston_meta_client.dart';
import '../logic/quilt_installer.dart';
import '../minecraft_launcher_scope.dart';

/// Instance creation flow: pick a name, a Minecraft version (releases by
/// default, snapshots optional, with search), optionally a mod loader, and
/// (if a loader is chosen) a loader version, then create.
class CreateInstanceWizard extends StatefulWidget {
  const CreateInstanceWizard({super.key});

  @override
  State<CreateInstanceWizard> createState() => _CreateInstanceWizardState();
}

class _CreateInstanceWizardState extends State<CreateInstanceWizard> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  bool _showSnapshots = false;
  String _search = '';
  String _loader = 'vanilla';

  VersionManifest? _manifest;
  String? _error;
  VersionManifestEntry? _selected;
  bool _creating = false;

  List<String> _loaderVersions = const [];
  String? _selectedLoaderVersion;
  bool _loadingLoaderVersions = false;
  String? _loaderVersionError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final manifest = await PistonMetaClient.instance.fetchManifest();
      if (!mounted) return;
      setState(() {
        _manifest = manifest;
        _selected = manifest.versions.firstWhere((v) => v.id == manifest.latestRelease);
        _nameController.text = manifest.latestRelease;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<VersionManifestEntry> get _filtered {
    final manifest = _manifest;
    if (manifest == null) return const [];
    return manifest.versions.where((v) {
      if (!_showSnapshots && !v.isRelease) return false;
      if (_search.isNotEmpty && !v.id.toLowerCase().contains(_search.toLowerCase())) return false;
      return true;
    }).toList();
  }

  void _selectLoader(String loader) {
    setState(() {
      _loader = loader;
      _selectedLoaderVersion = null;
      _loaderVersions = const [];
      _loaderVersionError = null;
    });
    if (loader != 'vanilla' && _selected != null) _loadLoaderVersions();
  }

  Future<void> _loadLoaderVersions() async {
    final mcVersion = _selected?.id;
    if (mcVersion == null || _loader == 'vanilla') return;
    setState(() {
      _loadingLoaderVersions = true;
      _loaderVersionError = null;
    });
    try {
      List<String> versions;
      switch (_loader) {
        case 'fabric':
          versions = (await FabricInstaller.fetchLoaderVersions(mcVersion))
              .map((v) => v.version)
              .toList();
        case 'quilt':
          versions = (await QuiltInstaller.fetchLoaderVersions(mcVersion))
              .map((v) => v.version)
              .toList();
        case 'forge':
          final promos = await ForgeInstaller.fetchPromotions();
          versions = {
            if (promos['$mcVersion-recommended'] != null) promos['$mcVersion-recommended']!,
            if (promos['$mcVersion-latest'] != null) promos['$mcVersion-latest']!,
          }.toList();
        case 'neoforge':
          versions = await NeoForgeInstaller.fetchVersions(mcVersion);
        default:
          versions = const [];
      }
      if (!mounted) return;
      setState(() {
        _loaderVersions = versions;
        _selectedLoaderVersion = versions.isEmpty ? null : versions.first;
        _loadingLoaderVersions = false;
        if (versions.isEmpty) {
          _loaderVersionError = 'No ${_loaderDisplayName(_loader)} builds found for $mcVersion.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLoaderVersions = false;
        _loaderVersionError = '$e';
      });
    }
  }

  Future<void> _create() async {
    final selected = _selected;
    if (selected == null || _nameController.text.trim().isEmpty) return;
    if (_loader != 'vanilla' && _selectedLoaderVersion == null) return;
    setState(() => _creating = true);
    final repository = MinecraftLauncherScope.of(context);
    try {
      await repository.createInstance(
        name: _nameController.text.trim(),
        versionId: selected.id,
        loader: _loader,
        loaderVersion: _loader == 'vanilla' ? null : _selectedLoaderVersion,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        title: const Text('New instance'),
        elevation: 0,
      ),
      body: _error != null
          ? Center(
              child: LumaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load Minecraft versions',
                subtitle: _error,
                action: LumaGhostButton(label: 'Retry', onTap: () {
                  setState(() => _error = null);
                  _load();
                }),
              ),
            )
          : _manifest == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
              : _buildForm(luma),
    );
  }

  Widget _buildForm(LumaPalette luma) {
    final canCreate = _selected != null &&
        _nameController.text.trim().isNotEmpty &&
        (_loader == 'vanilla' || _selectedLoaderVersion != null);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Name', style: TextStyle(color: luma.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Instance name')),
          const SizedBox(height: 20),
          Text('Mod loader', style: TextStyle(color: luma.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _LoaderChip(label: 'Vanilla', selected: _loader == 'vanilla', onTap: () => _selectLoader('vanilla')),
              for (final l in const ['Fabric', 'Forge', 'NeoForge', 'Quilt'])
                _LoaderChip(
                  label: l,
                  selected: _loader == l.toLowerCase(),
                  onTap: () => _selectLoader(l.toLowerCase()),
                ),
            ],
          ),
          if (_loader != 'vanilla') ...[
            const SizedBox(height: 14),
            Text('${_loaderDisplayName(_loader)} version',
                style: TextStyle(color: luma.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (_loadingLoaderVersions)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_loaderVersionError != null)
              Text(_loaderVersionError!, style: TextStyle(color: luma.textMuted, fontSize: 12))
            else
              DropdownButton<String>(
                value: _selectedLoaderVersion,
                items: [
                  for (final v in _loaderVersions) DropdownMenuItem(value: v, child: Text(v)),
                ],
                onChanged: (v) => setState(() => _selectedLoaderVersion = v),
              ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Version', style: TextStyle(color: luma.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Show snapshots', style: TextStyle(color: luma.textMuted, fontSize: 12)),
              Switch(
                value: _showSnapshots,
                onChanged: (v) => setState(() => _showSnapshots = v),
              ),
            ],
          ),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(hintText: 'Search versions…', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LumaCard(
              padding: EdgeInsets.zero,
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, i) {
                  final v = _filtered[i];
                  final selected = v.id == _selected?.id;
                  return ListTile(
                    dense: true,
                    selected: selected,
                    selectedTileColor: luma.accentSubtle,
                    title: Text(v.id, style: TextStyle(color: luma.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(v.type, style: TextStyle(color: luma.textMuted, fontSize: 12)),
                    onTap: () => setState(() {
                      _selected = v;
                      if (_nameController.text.isEmpty ||
                          _manifest!.versions.any((m) => m.id == _nameController.text)) {
                        _nameController.text = v.id;
                      }
                      if (_loader != 'vanilla') _loadLoaderVersions();
                    }),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: LumaPrimaryButton(
              label: 'Create',
              icon: Icons.add_rounded,
              loading: _creating,
              onTap: canCreate ? _create : null,
            ),
          ),
        ],
      ),
    );
  }
}

String _loaderDisplayName(String loader) => switch (loader) {
      'fabric' => 'Fabric',
      'forge' => 'Forge',
      'neoforge' => 'NeoForge',
      'quilt' => 'Quilt',
      _ => loader,
    };

class _LoaderChip extends StatelessWidget {
  const _LoaderChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? luma.accentSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? luma.accent : luma.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? luma.accent : luma.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
