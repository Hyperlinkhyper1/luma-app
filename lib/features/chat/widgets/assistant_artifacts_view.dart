import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/widgets.dart';
import '../../../theme/luma_theme.dart';
import '../data/chat_repository.dart';
import 'assistant_file_panel.dart';
import 'package:luma/l10n/app_localizations.dart';

/// Opens a generated file in luma's own preview rather than handing it to
/// whatever app the system has registered, which may be none.
Future<void> openAssistantArtifact(BuildContext context, String path) =>
    openAssistantFile(context, path);

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

enum _ArtifactFilter { all, images, files }

class AssistantArtifactsView extends StatefulWidget {
  const AssistantArtifactsView({
    super.key,
    required this.repository,
    required this.onOpenChat,
  });
  final ChatRepository repository;
  final ValueChanged<int> onOpenChat;
  @override
  State<AssistantArtifactsView> createState() => _AssistantArtifactsViewState();
}

class _AssistantArtifactsViewState extends State<AssistantArtifactsView> {
  late final Future<void> _indexed = widget.repository.indexExistingArtifacts();
  String _query = '';
  _ArtifactFilter _filter = _ArtifactFilter.all;
  bool _searching = false;
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _indexed,
    builder: (context, indexed) => StreamBuilder<List<ChatArtifactRecord>>(
      stream: widget.repository.watchArtifacts(),
      builder: (context, snapshot) {
        final luma = context.luma;
        final textTheme = Theme.of(context).textTheme;
        final t = L.of(context);
        final artifacts = snapshot.data ?? const <ChatArtifactRecord>[];
        final files = artifacts
            .where(
              (file) =>
                  file.name.toLowerCase().contains(_query) &&
                  (_filter == _ArtifactFilter.all ||
                      (_filter == _ArtifactFilter.images) ==
                          file.mimeType.startsWith('image/')),
            )
            .toList();
        final months = <String, List<ChatArtifactRecord>>{};
        for (final file in files) {
          final date = file.createdAt.toLocal();
          months.putIfAbsent(_monthNames[date.month - 1], () => []).add(file);
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: context.isPhoneWidth
                  ? const EdgeInsets.fromLTRB(16, 24, 16, 32)
                  : const EdgeInsets.fromLTRB(24, 40, 24, 40),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    t.assistantArtifactsTitle,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: LumaSegmentedTabs(
                        tabs: [t.commonAll, 'Images', 'Files'],
                        selectedIndex: _filter.index,
                        onSelect: (index) => setState(
                          () => _filter = _ArtifactFilter.values[index],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: t.commonSearch,
                      isSelected: _searching,
                      icon: Icon(
                        Icons.search_rounded,
                        color: luma.textSecondary,
                      ),
                      selectedIcon: Icon(
                        Icons.search_rounded,
                        color: luma.accent,
                      ),
                      onPressed: () => setState(() {
                        _searching = !_searching;
                        if (!_searching) _query = '';
                      }),
                    ),
                  ],
                ),
                if (_searching)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: TextField(
                      autofocus: true,
                      onChanged: (value) =>
                          setState(() => _query = value.toLowerCase().trim()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search artifacts',
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (snapshot.hasError || indexed.hasError)
                  Text(
                    t.assistantArtifactsLoadFailed,
                    style: TextStyle(color: luma.danger),
                  )
                else if (!snapshot.hasData)
                  const LinearProgressIndicator()
                else if (files.isEmpty)
                  LumaEmptyState(
                    icon: artifacts.isEmpty
                        ? Icons.folder_open_rounded
                        : Icons.search_off_rounded,
                    title: artifacts.isEmpty
                        ? t.assistantArtifactsEmpty
                        : t.commonNoResults,
                  ),
                for (final entry in months.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      header: true,
                      child: Text(
                        entry.key,
                        style: textTheme.labelLarge?.copyWith(
                          color: luma.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  LumaCard(
                    padding: const EdgeInsets.all(6),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          for (final file in entry.value) _row(context, file),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _row(BuildContext context, ChatArtifactRecord file) {
    final luma = context.luma;
    final decor = context.lumaDecor;
    final textTheme = Theme.of(context).textTheme;
    final t = L.of(context);
    final isPicture = file.mimeType.startsWith('image/');
    final canPreview = isPicture && file.mimeType != 'image/svg+xml';
    final date = file.createdAt.toLocal();
    const thumbnailSize = 42.0;
    final fallbackIcon = LumaIconBadge(
      icon: isPicture ? Icons.image_outlined : Icons.insert_drive_file_outlined,
      color: luma.accent,
      size: thumbnailSize,
    );
    final created = Text(
      'Created ${_monthNames[date.month - 1].substring(0, 3)} ${date.day}',
      style: textTheme.bodySmall?.copyWith(color: luma.textSecondary),
    );
    return InkWell(
      customBorder: decor.pillShape(),
      hoverColor: luma.surfaceHover,
      onTap: () => openAssistantArtifact(context, file.path),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 0, 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showInlineDate =
                constraints.maxWidth >= 360 &&
                MediaQuery.textScalerOf(context).scale(12) <= 16;
            return Row(
              children: [
                if (canPreview)
                  ClipPath.shape(
                    shape: decor.shape(
                      BorderRadius.circular(
                        thumbnailSize * decor.badgeRadiusFactor,
                      ),
                    ),
                    child: Image.file(
                      File(file.path),
                      width: thumbnailSize,
                      height: thumbnailSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallbackIcon,
                    ),
                  )
                else
                  fallbackIcon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                      if (!showInlineDate) created,
                    ],
                  ),
                ),
                if (showInlineDate) ...[const SizedBox(width: 16), created],
                PopupMenuButton<String>(
                  tooltip: t.commonMore,
                  color: luma.surface,
                  surfaceTintColor: Colors.transparent,
                  shape: decor.pillShape(side: BorderSide(color: luma.border)),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: luma.textSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'open') {
                      openAssistantArtifact(context, file.path);
                    } else if (value == 'save') {
                      _save(context, file);
                    } else if (value == 'chat' && file.conversationId != null) {
                      widget.onOpenChat(file.conversationId!);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'open', child: Text(t.commonOpen)),
                    PopupMenuItem(
                      value: 'save',
                      child: Text(t.assistantArtifactSaveCopy),
                    ),
                    if (file.conversationId != null)
                      PopupMenuItem(
                        value: 'chat',
                        child: Text(t.assistantArtifactViewChat),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, ChatArtifactRecord file) async {
    try {
      final bytes = await File(file.path).readAsBytes();
      final target = await FilePicker.saveFile(
        dialogTitle: 'Save artifact',
        fileName: file.name,
        bytes: Platform.isAndroid || Platform.isIOS ? bytes : null,
      );
      if (target != null && !Platform.isAndroid && !Platform.isIOS) {
        await File(target).writeAsBytes(bytes, flush: true);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the file: $error')),
        );
      }
    }
  }
}
