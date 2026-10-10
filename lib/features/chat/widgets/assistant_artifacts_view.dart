import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';

import '../../../theme/luma_theme.dart';
import '../data/chat_repository.dart';

Future<void> openAssistantArtifact(BuildContext context, String path) async {
  String? error;
  try {
    if (!await File(path).exists()) {
      error = 'This file is no longer on this device.';
    } else {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) error = result.message;
    }
  } catch (failure) {
    error = 'Could not open the file: $failure';
  }
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

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
  String _filter = 'All';
  bool _searching = false;
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _indexed,
    builder: (context, indexed) => StreamBuilder<List<ChatArtifactRecord>>(
      stream: widget.repository.watchArtifacts(),
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final background = isDark
            ? const Color(0xFF141414)
            : context.luma.background;
        final surface = isDark ? const Color(0xFF202020) : context.luma.surface;
        final border = isDark ? const Color(0xFF333333) : context.luma.border;
        final selectedFill = isDark
            ? const Color(0xFF2C2C2C)
            : context.luma.surfaceHover;
        final files = (snapshot.data ?? const <ChatArtifactRecord>[])
            .where(
              (file) =>
                  file.name.toLowerCase().contains(_query) &&
                  (_filter == 'All' ||
                      (_filter == 'Images') ==
                          file.mimeType.startsWith('image/')),
            )
            .toList();
        final months = <String, List<ChatArtifactRecord>>{};
        for (final file in files) {
          final date = file.createdAt.toLocal();
          months.putIfAbsent(_monthNames[date.month - 1], () => []).add(file);
        }
        return ColoredBox(
          color: background,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
                children: [
                  Text(
                    'Artifacts',
                    style: TextStyle(
                      fontSize: 30,
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const ['Times New Roman', 'serif'],
                      fontWeight: FontWeight.w500,
                      color: context.luma.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      for (final filter in ['All', 'Images', 'Files'])
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _filter = filter),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _filter == filter
                                    ? selectedFill
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                filter,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _filter == filter
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _filter == filter
                                      ? context.luma.textPrimary
                                      : context.luma.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Search',
                        icon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: _searching
                              ? context.luma.textPrimary
                              : context.luma.textSecondary,
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
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: 'Search artifacts',
                          fillColor: surface,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: border),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  if (snapshot.hasError || indexed.hasError)
                    const Text('Could not load artifacts.'),
                  if (!snapshot.hasData) const LinearProgressIndicator(),
                  if (snapshot.hasData && files.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text(
                        'No artifacts found. Generated files and pictures will appear here.',
                        style: TextStyle(color: context.luma.textMuted),
                      ),
                    ),
                  for (final entry in months.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.luma.textMuted,
                        ),
                      ),
                    ),
                    for (final file in entry.value)
                      _row(context, file, surface, border),
                    const SizedBox(height: 22),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _row(
    BuildContext context,
    ChatArtifactRecord file,
    Color surface,
    Color border,
  ) {
    final isPicture = file.mimeType.startsWith('image/');
    final canPreview = isPicture && file.mimeType != 'image/svg+xml';
    final date = file.createdAt.toLocal();
    final fallbackIcon = Icon(
      isPicture ? Icons.image_outlined : Icons.code_rounded,
      size: 20,
      color: context.luma.textSecondary,
    );
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => openAssistantArtifact(context, file.path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border),
              ),
              child: canPreview
                  ? Image.file(
                      File(file.path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallbackIcon,
                    )
                  : fallbackIcon,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: context.luma.textPrimary,
                ),
              ),
            ),
            Text(
              'Created ${_monthNames[date.month - 1].substring(0, 3)} ${date.day}',
              style: TextStyle(fontSize: 13, color: context.luma.textMuted),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: context.luma.textSecondary,
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
                const PopupMenuItem(value: 'open', child: Text('Open')),
                const PopupMenuItem(value: 'save', child: Text('Save a copy')),
                if (file.conversationId != null)
                  const PopupMenuItem(value: 'chat', child: Text('View chat')),
              ],
            ),
          ],
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
