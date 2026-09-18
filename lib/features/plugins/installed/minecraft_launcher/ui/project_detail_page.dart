import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/minecraft_launcher_database.dart';
import '../logic/mod_install_flow.dart';
import '../logic/modrinth_api_client.dart';
import '../minecraft_launcher_repository.dart';
import 'hover_sync_scroll.dart';
import 'markdown_lite.dart';
import 'modrinth_ui.dart';

/// A project's page, laid out the way Modrinth's own is: a header carrying
/// the icon, author, summary, stats and the install action; a gallery strip
/// you can open full-screen; and a Description / Versions switch below.
///
/// [instance] is optional — reached from a browse page it is already known,
/// but from global search there is no target yet, so the first install asks
/// which instance it should land in.
class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.instance,
    required this.kind,
    required this.repository,
  });

  final String projectId;
  final McInstance? instance;
  final String kind;
  final MinecraftLauncherRepository repository;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  ModrinthProject? _project;
  List<ModrinthVersion> _versions = const [];
  List<ModrinthTeamMember> _members = const [];
  Set<String> _installedVersionIds = {};
  String? _error;
  bool _showVersions = false;
  final _installing = <String>{};
  McInstance? _target;

  @override
  void initState() {
    super.initState();
    _target = widget.instance;
    _load();
  }

  Future<void> _load() async {
    try {
      final project = await ModrinthApiClient.instance.getProject(widget.projectId);
      if (!mounted) return;
      setState(() => _project = project);

      // The team lookup is decoration — a failure there shouldn't cost the
      // user the page.
      ModrinthApiClient.instance.getProjectMembers(widget.projectId).then(
        (members) {
          if (mounted) setState(() => _members = members);
        },
        onError: (_) {},
      );

      await _loadVersionsFor(_target);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _loadVersionsFor(McInstance? instance) async {
    if (instance == null) {
      setState(() {
        _versions = const [];
        _installedVersionIds = {};
      });
      return;
    }
    final versions = await ModInstallFlow.compatibleVersions(
      projectId: widget.projectId,
      instance: instance,
      kind: widget.kind,
    );
    final installed = await widget.repository.watchInstalledContent(instance.id).first;
    if (!mounted) return;
    setState(() {
      _versions = versions;
      _installedVersionIds = installed
          .where((r) => r.projectId == widget.projectId)
          .map((r) => r.versionId)
          .whereType<String>()
          .toSet();
    });
  }

  /// Resolves the instance an install should go into, asking the user when
  /// the page was opened without one.
  Future<McInstance?> _resolveTarget() async {
    if (_target != null) return _target;
    final instances = await widget.repository.watchInstances().first;
    if (!mounted) return null;
    if (instances.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Create an instance first.')));
      return null;
    }
    final picked = await pickInstance(
      context,
      instances,
      projectTitle: _project?.title,
    );
    if (picked == null) return null;
    setState(() => _target = picked);
    await _loadVersionsFor(picked);
    return picked;
  }

  Future<void> _changeTarget() async {
    final instances = await widget.repository.watchInstances().first;
    if (!mounted || instances.isEmpty) return;
    final picked = await pickInstance(
      context,
      instances,
      title: 'Install into which instance?',
      projectTitle: _project?.title,
    );
    if (picked == null) return;
    setState(() => _target = picked);
    await _loadVersionsFor(picked);
  }

  Future<void> _install(ModrinthVersion version) async {
    final project = _project;
    if (project == null) return;
    final instance = await _resolveTarget();
    if (instance == null || !mounted) return;
    setState(() => _installing.add(version.id));
    final ok = await ModInstallFlow.install(
      context: context,
      repository: widget.repository,
      instance: instance,
      project: project,
      version: version,
      kind: widget.kind,
    );
    if (!mounted) return;
    setState(() => _installing.remove(version.id));
    if (ok) await _loadVersionsFor(instance);
  }

  Future<void> _installBest() async {
    final instance = await _resolveTarget();
    if (instance == null || !mounted) return;
    final version = ModInstallFlow.bestVersion(_versions);
    if (version == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No build of this for ${instance.versionId}'
            '${instance.loader == 'vanilla' ? '' : ' on ${instance.loader}'}.',
          ),
        ),
      );
      return;
    }
    await _install(version);
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final project = _project;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        title: Text(project?.title ?? 'Loading…'),
        elevation: 0,
        actions: [
          if (project != null)
            IconButton(
              tooltip: 'Open on Modrinth',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () => _open(
                ModrinthApiClient.projectUrl(project.projectType, project.slug),
              ),
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: LumaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load this project',
                subtitle: _error,
              ),
            )
          : project == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
              : _buildBody(luma, project),
    );
  }

  Widget _buildBody(LumaPalette luma, ModrinthProject project) {
    final gallery = project.orderedGallery;
    return HoverSyncScroll(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _header(luma, project),
          if (gallery.isNotEmpty) ...[
            const SizedBox(height: 20),
            _sectionLabel(luma, 'Gallery', '${gallery.length} image${gallery.length == 1 ? '' : 's'}'),
            const SizedBox(height: 10),
            _galleryStrip(luma, gallery),
          ],
          const SizedBox(height: 24),
          _switcher(luma),
          const SizedBox(height: 16),
          if (_showVersions) _versionList(luma) else _description(luma, project),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

  Widget _header(LumaPalette luma, ModrinthProject project) {
    final accent = modrinthAccentOf(project.color) ?? luma.accent;
    final owner = _members
        .firstWhere(
          (m) => m.role.toLowerCase() == 'owner',
          orElse: () => _members.isEmpty
              ? ModrinthTeamMember(username: '', role: '', avatarUrl: null)
              : _members.first,
        )
        .username;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModrinthThumb(
                url: project.iconUrl,
                kind: project.projectType,
                accent: accent,
                size: 88,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (owner.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'by $owner',
                        style: TextStyle(color: luma.textMuted, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      project.description,
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        ModrinthStat(
                          icon: Icons.download_rounded,
                          value: formatCompactCount(project.downloads),
                          label: 'downloads',
                          emphasis: true,
                        ),
                        ModrinthStat(
                          icon: Icons.favorite_rounded,
                          value: formatCompactCount(project.followers),
                          label: 'followers',
                        ),
                        if (project.updated != null)
                          ModrinthStat(
                            icon: Icons.update_rounded,
                            value: relativeTime(project.updated),
                            label: 'updated',
                          ),
                        if (project.licenseName != null)
                          ModrinthStat(
                            icon: Icons.gavel_rounded,
                            value: project.licenseName!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (project.categories.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in project.categories)
                  ModrinthTag(label: prettyTag(tag), icon: modrinthTagIcon(tag)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Divider(color: luma.border, height: 1),
          const SizedBox(height: 16),
          _actionRow(luma, project),
        ],
      ),
    );
  }

  Widget _actionRow(LumaPalette luma, ModrinthProject project) {
    final target = _target;
    final busy = _installing.isNotEmpty;
    final best = ModInstallFlow.bestVersion(_versions);
    final alreadyInstalled =
        best != null && _installedVersionIds.contains(best.id);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ModrinthInstallButton(
          compact: false,
          label: target == null ? 'Install into…' : 'Install',
          installed: alreadyInstalled,
          busy: busy,
          tooltip: target == null
              ? 'Pick an instance to install into'
              : 'Install the newest compatible build into ${target.name}',
          onInstall: _installBest,
        ),
        _targetChip(luma, target),
        for (final link in <(IconData, String, String?)>[
          (Icons.code_rounded, 'Source', project.sourceUrl),
          (Icons.bug_report_rounded, 'Issues', project.issuesUrl),
          (Icons.menu_book_rounded, 'Wiki', project.wikiUrl),
          (Icons.forum_rounded, 'Discord', project.discordUrl),
        ])
          if (link.$3 != null)
            _linkButton(luma, icon: link.$1, label: link.$2, url: link.$3!),
      ],
    );
  }

  /// The install target, shown as a chip so it is obvious where a click
  /// will put the files — and swappable in one tap.
  Widget _targetChip(LumaPalette luma, McInstance? target) {
    return InkWell(
      onTap: _changeTarget,
      borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: luma.background,
          borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
          border: Border.all(color: luma.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videogame_asset_rounded, size: 16, color: luma.accent),
            const SizedBox(width: 8),
            Text(
              target == null
                  ? 'Choose instance'
                  : '${target.name} · ${target.versionId}',
              style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more_rounded, size: 16, color: luma.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _linkButton(
    LumaPalette luma, {
    required IconData icon,
    required String label,
    required String url,
  }) {
    return InkWell(
      onTap: () => _open(url),
      borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
          border: Border.all(color: luma.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: luma.textMuted),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Gallery ───────────────────────────────────────────────────────────

  Widget _galleryStrip(LumaPalette luma, List<ModrinthGalleryImage> gallery) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gallery.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final image = gallery[i];
          return _GalleryThumb(
            image: image,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => GalleryViewerPage(images: gallery, initialIndex: i),
              fullscreenDialog: true,
            )),
          );
        },
      ),
    );
  }

  // ── Description / Versions ────────────────────────────────────────────

  Widget _switcher(LumaPalette luma) {
    Widget tab(String label, bool selected, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? luma.accentSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(context.lumaDecor.pillRadius),
            border: Border.all(color: selected ? luma.accent : luma.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? luma.accent : luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab('Description', !_showVersions, () => setState(() => _showVersions = false)),
        const SizedBox(width: 8),
        tab(
          _versions.isEmpty ? 'Versions' : 'Versions (${_versions.length})',
          _showVersions,
          () => setState(() => _showVersions = true),
        ),
      ],
    );
  }

  Widget _sectionLabel(LumaPalette luma, String title, String? trailing) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: luma.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(trailing, style: TextStyle(color: luma.textMuted, fontSize: 12)),
      ],
    );
  }

  Widget _description(LumaPalette luma, ModrinthProject project) {
    return LumaCard(
      child: MarkdownLite(source: project.body, onLinkTap: _open),
    );
  }

  Widget _versionList(LumaPalette luma) {
    final target = _target;
    if (target == null) {
      return LumaCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Pick an instance to see which builds fit it.',
                style: TextStyle(color: luma.textSecondary, fontSize: 13),
              ),
            ),
            LumaPrimaryButton(
              label: 'Choose instance',
              icon: Icons.videogame_asset_rounded,
              onTap: _changeTarget,
            ),
          ],
        ),
      );
    }
    if (_versions.isEmpty) {
      return LumaCard(
        child: Text(
          'No build of this works with ${target.versionId}'
          '${target.loader == 'vanilla' ? '' : ' on ${prettyTag(target.loader)}'}.',
          style: TextStyle(color: luma.textSecondary, fontSize: 13),
        ),
      );
    }
    return Column(
      children: [
        for (final v in _versions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _versionCard(luma, v),
          ),
      ],
    );
  }

  Widget _versionCard(LumaPalette luma, ModrinthVersion version) {
    final channelColor = switch (version.versionType) {
      'release' => luma.success,
      'beta' => luma.warning,
      _ => luma.danger,
    };
    final installed = _installedVersionIds.contains(version.id);
    return LumaCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        version.name.isEmpty ? version.versionNumber : version.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ModrinthTag(
                      label: prettyTag(version.versionType),
                      tone: channelColor,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final loader in version.loaders)
                      ModrinthTag(label: prettyTag(loader)),
                    for (final game in version.gameVersions.take(4))
                      ModrinthTag(label: game),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    ModrinthStat(
                      icon: Icons.download_rounded,
                      value: formatCompactCount(version.downloads),
                    ),
                    ModrinthStat(
                      icon: Icons.schedule_rounded,
                      value: relativeTime(version.datePublished),
                    ),
                    if (version.files.isNotEmpty)
                      ModrinthStat(
                        icon: Icons.insert_drive_file_rounded,
                        value: formatFileSize(version.primaryFile.size),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ModrinthInstallButton(
            compact: false,
            installed: installed,
            busy: _installing.contains(version.id),
            onInstall: () => _install(version),
          ),
        ],
      ),
    );
  }
}

class _GalleryThumb extends StatefulWidget {
  const _GalleryThumb({required this.image, required this.onTap});
  final ModrinthGalleryImage image;
  final VoidCallback onTap;

  @override
  State<_GalleryThumb> createState() => _GalleryThumbState();
}

class _GalleryThumbState extends State<_GalleryThumb> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 250,
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovering ? luma.accent : luma.border,
              width: _hovering ? 1.5 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.image.url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(Icons.broken_image_rounded, color: luma.textMuted),
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
              if (widget.image.title != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                    child: Text(
                      widget.image.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen gallery viewer: swipe or arrow-key between shots, pinch or
/// scroll to zoom, caption underneath.
class GalleryViewerPage extends StatefulWidget {
  const GalleryViewerPage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  final List<ModrinthGalleryImage> images;
  final int initialIndex;

  @override
  State<GalleryViewerPage> createState() => _GalleryViewerPageState();
}

class _GalleryViewerPageState extends State<GalleryViewerPage> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final next = (_index + delta).clamp(0, widget.images.length - 1);
    if (next == _index) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          current.title ?? 'Image ${_index + 1} of ${widget.images.length}',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: KeyboardListener(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) _step(1);
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _step(-1);
          if (event.logicalKey == LogicalKeyboardKey.escape) Navigator.pop(context);
        },
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: widget.images.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => InteractiveViewer(
                      maxScale: 5,
                      child: Center(
                        child: Image.network(
                          widget.images[i].url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_index > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _arrow(Icons.chevron_left_rounded, () => _step(-1)),
                    ),
                  if (_index < widget.images.length - 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: _arrow(Icons.chevron_right_rounded, () => _step(1)),
                    ),
                ],
              ),
            ),
            if (current.description != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Text(
                  current.description!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: Colors.white12,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
      );
}
