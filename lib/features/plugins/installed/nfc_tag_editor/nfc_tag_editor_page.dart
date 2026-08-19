import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart' show NdefMessage;

import '../../../../app/widgets.dart';
import '../../../../storage/storage_guard.dart';
import '../../../../theme/luma_theme.dart';
import 'nfc_record.dart';
import 'nfc_record_editor_sheet.dart';
import 'nfc_record_tile.dart';
import 'nfc_tag_editor_platform.dart';
import 'nfc_tag_service.dart';
import 'nfc_tag_store.dart';

/// The NFC Tag Editor plugin: scan a physical NFC tag to see and edit its
/// NDEF records — text, links, Wi-Fi details, contact cards, app shortcuts
/// and more — then write the result back, to the same tag or a different
/// one. Also keeps reusable write templates and a history of every tag
/// scanned or written.
class NfcTagEditorPage extends StatefulWidget {
  const NfcTagEditorPage({super.key});

  @override
  State<NfcTagEditorPage> createState() => _NfcTagEditorPageState();
}

enum _BusyMode { scanning, writing }

class _NfcTagEditorPageState extends State<NfcTagEditorPage> {
  int _tabIndex = 0;

  ScannedNfcTag? _tag;
  List<EditableNdefRecord> _records = [];
  bool _hasStarted = false;

  bool _busy = false;
  _BusyMode? _busyMode;
  Object _busyToken = Object();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: LumaSegmentedTabs(
              tabs: const ['Editor', 'Templates', 'History'],
              selectedIndex: _tabIndex,
              onSelect: (i) => setState(() => _tabIndex = i),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: [
                _buildEditorTab(context),
                _TemplatesTab(onUseTemplate: _loadTemplate),
                _HistoryTab(onReopen: _loadFromHistory),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Editor tab -----------------------------------------------------

  Widget _buildEditorTab(BuildContext context) {
    if (!NfcTagEditorPlatform.isSupported) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: LumaEmptyState(
            icon: Icons.phonelink_erase_rounded,
            title: 'Android only',
            subtitle: NfcTagEditorPlatform.unsupportedNotice,
          ),
        ),
      );
    }
    if (_busy) {
      return _BusyCard(mode: _busyMode!, onCancel: _cancelBusy);
    }
    if (!_hasStarted) {
      return _buildHero(context);
    }
    return _buildLoadedEditor(context);
  }

  Widget _buildHero(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.nfc_rounded, color: luma.accent, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              "Scan a tag to see what's on it",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hold any NFC tag or sticker to your phone to read and edit '
              'its records — or start from scratch and write a brand-new '
              'tag.',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            LumaPrimaryButton(
              label: 'Scan a tag',
              icon: Icons.nfc_rounded,
              onTap: _startScan,
            ),
            const SizedBox(height: 10),
            LumaGhostButton(
              label: 'Start from scratch',
              icon: Icons.add_rounded,
              onTap: _startFromScratch,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorNote(message: _error!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedEditor(BuildContext context) {
    final luma = context.luma;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_tag != null) ...[
                _TagInfoCard(tag: _tag!, records: _records),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Records',
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _SquareIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Add record',
                    onTap: _addRecord,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _records.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Center(
                    child: LumaEmptyState(
                      icon: Icons.playlist_add_rounded,
                      title: 'No records yet',
                      subtitle: 'Add a record above — text, a link, Wi-Fi '
                          'details, a contact card and more.',
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: _records.length,
                  onReorderItem: _onReorder,
                  itemBuilder: (context, i) {
                    final record = _records[i];
                    return Padding(
                      key: ValueKey(record.id),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: NfcRecordTile(
                        record: record,
                        onEdit: record.kind == NfcRecordKind.raw
                            ? null
                            : () => _editRecord(i),
                        onDuplicate: () => _duplicateRecord(i),
                        onDelete: () => _deleteRecord(i),
                        dragHandle: ReorderableDragStartListener(
                          index: i,
                          child: Icon(Icons.drag_handle_rounded,
                              color: luma.textMuted, size: 20),
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildBottomBar(context),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(top: BorderSide(color: luma.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: LumaPrimaryButton(
                  label: 'Write to tag',
                  icon: Icons.upload_rounded,
                  expand: true,
                  onTap: _records.isEmpty ? null : () => _startWrite(),
                ),
              ),
              const SizedBox(width: 8),
              _OverflowButton(
                onSaveTemplate: _records.isEmpty ? null : _showSaveTemplateDialog,
                onLockAndWrite: _records.isEmpty ? null : _confirmLockAndWrite,
                onStartOver: _startOver,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Works on the tag you scanned or a different one — just hold '
            "whichever you want to write to when it's ready.",
            textAlign: TextAlign.center,
            style: TextStyle(color: luma.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ---- Record list actions ---------------------------------------------

  Future<void> _addRecord() async {
    final record = await showNfcRecordEditor(context);
    if (record == null || !mounted) return;
    setState(() => _records.add(record));
  }

  Future<void> _editRecord(int index) async {
    final updated = await showNfcRecordEditor(context, existing: _records[index]);
    if (updated == null || !mounted) return;
    setState(() => _records[index] = updated);
  }

  void _duplicateRecord(int index) {
    setState(() => _records.insert(index + 1, _records[index].copyWith()));
  }

  void _deleteRecord(int index) {
    setState(() => _records.removeAt(index));
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _records.removeAt(oldIndex);
      _records.insert(newIndex, item);
    });
  }

  void _startFromScratch() {
    setState(() {
      _hasStarted = true;
      _tag = null;
      _records = [];
      _error = null;
    });
  }

  Future<void> _startOver() async {
    if (_records.isEmpty) {
      setState(() {
        _hasStarted = false;
        _tag = null;
      });
      return;
    }
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Start over?', style: TextStyle(color: luma.textPrimary, fontSize: 16)),
        content: Text(
          'This clears every record in the editor. Anything already written '
          'to a tag is unaffected.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Start over', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _hasStarted = false;
        _tag = null;
        _records = [];
        _error = null;
      });
    }
  }

  // ---- Scan / write ------------------------------------------------------

  Future<void> _startScan() async {
    final token = Object();
    _busyToken = token;
    setState(() {
      _busy = true;
      _busyMode = _BusyMode.scanning;
      _error = null;
    });
    try {
      final tag = await NfcTagService.scan();
      if (_busyToken != token || !mounted) return;
      setState(() {
        _tag = tag;
        _records = List.of(tag.records);
        _busy = false;
        _hasStarted = true;
      });
      unawaited(NfcTagStore.instance.addHistory(NfcHistoryEntry(
        id: newNfcRecordId(),
        timestamp: DateTime.now(),
        direction: NfcHistoryDirection.scanned,
        records: tag.records,
        techLabel: tag.techLabel,
        uid: tag.uid,
        locked: tag.isLocked,
      )));
    } on NfcTagEditorException catch (e) {
      if (_busyToken != token || !mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (_busyToken != token || !mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong reading that tag.';
      });
    }
  }

  Future<void> _startWrite({bool lock = false}) async {
    if (_records.isEmpty) return;
    final token = Object();
    _busyToken = token;
    setState(() {
      _busy = true;
      _busyMode = _BusyMode.writing;
    });
    try {
      await NfcTagService.write(_records, lock: lock);
      if (_busyToken != token || !mounted) return;
      setState(() => _busy = false);
      unawaited(NfcTagStore.instance.addHistory(NfcHistoryEntry(
        id: newNfcRecordId(),
        timestamp: DateTime.now(),
        direction: NfcHistoryDirection.written,
        records: _records,
        techLabel: _tag?.techLabel,
        uid: _tag?.uid,
        locked: lock,
      )));
      _snack(
        lock ? 'Written and locked read-only.' : 'Written to the tag.',
        action: SnackBarAction(label: 'Write another', onPressed: () => _startWrite(lock: lock)),
      );
    } on NfcTagEditorException catch (e) {
      if (_busyToken != token || !mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    } catch (_) {
      if (_busyToken != token || !mounted) return;
      setState(() => _busy = false);
      _snack("Couldn't write to that tag.");
    }
  }

  void _cancelBusy() {
    _busyToken = Object();
    NfcTagService.stop();
    setState(() => _busy = false);
  }

  void _snack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), action: action),
    );
  }

  Future<void> _showSaveTemplateDialog() async {
    final luma = context.luma;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Save as template', style: TextStyle(color: luma.textPrimary, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: luma.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'e.g. Guest Wi-Fi',
            hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
            filled: true,
            fillColor: luma.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: luma.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: luma.accent),
            ),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text('Save', style: TextStyle(color: luma.accent)),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) return;
    try {
      await NfcTagStore.instance.saveTemplate(trimmed, _records);
      _snack('Saved "$trimmed".');
    } on StorageLimitExceededException catch (e) {
      _snack('$e');
    }
  }

  Future<void> _confirmLockAndWrite() async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Write & lock this tag?', style: TextStyle(color: luma.textPrimary, fontSize: 16)),
        content: Text(
          'This writes the records below, then makes the tag permanently '
          "read-only. It can never be written to again — not by luma, not "
          'by any other app.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Write & lock', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) _startWrite(lock: true);
  }

  // ---- Templates / history reuse -----------------------------------------

  void _loadTemplate(NfcTagTemplate template) {
    setState(() {
      _tag = null;
      _records = template.records.map((r) => r.copyWith()).toList();
      _hasStarted = true;
      _tabIndex = 0;
      _error = null;
    });
  }

  void _loadFromHistory(NfcHistoryEntry entry) {
    setState(() {
      _tag = null;
      _records = entry.records.map((r) => r.copyWith()).toList();
      _hasStarted = true;
      _tabIndex = 0;
      _error = null;
    });
  }
}

// ---- Small shared widgets --------------------------------------------------

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: luma.accentSubtle,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(width: 36, height: 36, child: Icon(icon, color: luma.accent, size: 20)),
        ),
      ),
    );
  }
}

class _OverflowButton extends StatelessWidget {
  const _OverflowButton({
    required this.onSaveTemplate,
    required this.onLockAndWrite,
    required this.onStartOver,
  });

  final VoidCallback? onSaveTemplate;
  final VoidCallback? onLockAndWrite;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'More',
        color: luma.surface,
        icon: Icon(Icons.more_vert_rounded, color: luma.textSecondary, size: 20),
        onSelected: (value) {
          switch (value) {
            case 'template':
              onSaveTemplate?.call();
              break;
            case 'lock':
              onLockAndWrite?.call();
              break;
            case 'reset':
              onStartOver();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'template',
            enabled: onSaveTemplate != null,
            child: Text('Save as template', style: TextStyle(color: luma.textPrimary, fontSize: 13.5)),
          ),
          PopupMenuItem(
            value: 'lock',
            enabled: onLockAndWrite != null,
            child: Text('Write & lock (read-only)', style: TextStyle(color: luma.danger, fontSize: 13.5)),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'reset',
            child: Text('Start over', style: TextStyle(color: luma.textPrimary, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: luma.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, color: luma.danger, size: 16),
          const SizedBox(width: 8),
          Flexible(child: Text(message, style: TextStyle(color: luma.danger, fontSize: 12.5))),
        ],
      ),
    );
  }
}

class _TagInfoCard extends StatelessWidget {
  const _TagInfoCard({required this.tag, required this.records});
  final ScannedNfcTag tag;
  final List<EditableNdefRecord> records;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    int? used;
    try {
      used = NdefMessage(records.map((r) => r.toNdefRecord()).toList()).byteLength;
    } catch (_) {
      used = null;
    }
    final max = tag.maxSize;
    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.nfc_rounded, color: luma.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tag.techLabel ?? 'NFC tag',
                  style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              if (tag.isLocked)
                _Badge(label: 'Read-only', color: luma.danger)
              else if (!tag.isNdef)
                _Badge(label: 'Blank — will format', color: luma.textMuted),
            ],
          ),
          if (tag.uid != null) ...[
            const SizedBox(height: 6),
            Text('UID ${tag.uid}', style: TextStyle(color: luma.textMuted, fontSize: 12)),
          ],
          if (used != null && max > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (used / max).clamp(0, 1).toDouble(),
                minHeight: 6,
                backgroundColor: luma.background,
                valueColor: AlwaysStoppedAnimation(used > max ? luma.danger : luma.accent),
              ),
            ),
            const SizedBox(height: 4),
            Text('$used / $max bytes', style: TextStyle(color: luma.textMuted, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

class _BusyCard extends StatefulWidget {
  const _BusyCard({required this.mode, required this.onCancel});
  final _BusyMode mode;
  final VoidCallback onCancel;

  @override
  State<_BusyCard> createState() => _BusyCardState();
}

class _BusyCardState extends State<_BusyCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final label = widget.mode == _BusyMode.scanning
        ? 'Hold a tag against your phone'
        : 'Hold the tag you want to write to';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.08)
                  .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: luma.accentSubtle, shape: BoxShape.circle),
                child: Icon(Icons.nfc_rounded, color: luma.accent, size: 44),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textPrimary, fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep it flat against the back of the phone until it beeps or vibrates.',
              textAlign: TextAlign.center,
              style: TextStyle(color: luma.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: 20),
            LumaGhostButton(label: 'Cancel', icon: Icons.close_rounded, onTap: widget.onCancel),
          ],
        ),
      ),
    );
  }
}

// ---- Templates tab ----------------------------------------------------

class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab({required this.onUseTemplate});
  final ValueChanged<NfcTagTemplate> onUseTemplate;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NfcTagStore.instance,
      builder: (context, _) {
        final store = NfcTagStore.instance;
        if (!store.loaded) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }
        final templates = store.templates;
        if (templates.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: LumaEmptyState(
                icon: Icons.bookmark_add_rounded,
                title: 'No templates yet',
                subtitle: 'Build a set of records in the Editor tab, then '
                    'save it here to write the same tag content again and '
                    'again — handy for a batch of stickers.',
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          itemCount: templates.length,
          itemBuilder: (context, i) {
            final template = templates[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TemplateCard(
                template: template,
                onUse: () => onUseTemplate(template),
                onDelete: () => _confirmDeleteTemplate(context, template),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteTemplate(BuildContext context, NfcTagTemplate template) async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Delete template?', style: TextStyle(color: luma.textPrimary, fontSize: 16)),
        content: Text(
          'This removes "${template.name}" — tags already written with it '
          'keep their content.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) await NfcTagStore.instance.deleteTemplate(template.id);
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onUse, required this.onDelete});
  final NfcTagTemplate template;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final kinds = template.records
        .map((r) => nfcRecordKindMeta(r.kind).label)
        .toSet()
        .join(' · ');
    return LumaCard(
      child: Row(
        children: [
          LumaIconBadge(icon: Icons.bookmark_rounded, color: luma.accent, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  template.records.isEmpty
                      ? 'No records'
                      : '${template.records.length} record'
                          '${template.records.length == 1 ? '' : 's'} · $kinds',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          LumaGhostButton(label: 'Use', icon: Icons.edit_rounded, onTap: onUse),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded, color: luma.textMuted, size: 20),
          ),
        ],
      ),
    );
  }
}

// ---- History tab --------------------------------------------------------

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.onReopen});
  final ValueChanged<NfcHistoryEntry> onReopen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NfcTagStore.instance,
      builder: (context, _) {
        final store = NfcTagStore.instance;
        if (!store.loaded) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }
        final history = store.history;
        if (history.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: LumaEmptyState(
                icon: Icons.history_rounded,
                title: 'No history yet',
                subtitle: 'Every tag you scan or write shows up here, so you '
                    'can revisit what was on it.',
              ),
            ),
          );
        }
        final luma = context.luma;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          itemCount: history.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _confirmClear(context),
                  icon: Icon(Icons.delete_sweep_rounded, size: 16, color: luma.textSecondary),
                  label: Text('Clear history', style: TextStyle(color: luma.textSecondary, fontSize: 12.5)),
                ),
              );
            }
            final entry = history[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HistoryCard(
                entry: entry,
                onTap: () => _showHistoryDetail(context, entry, onReopen),
                onDelete: () => NfcTagStore.instance.removeHistory(entry.id),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final luma = context.luma;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text('Clear history?', style: TextStyle(color: luma.textPrimary, fontSize: 16)),
        content: Text(
          'Every scan and write in the list is removed. Saved templates are '
          'unaffected.',
          style: TextStyle(color: luma.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Clear', style: TextStyle(color: luma.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) await NfcTagStore.instance.clearHistory();
  }

  void _showHistoryDetail(
    BuildContext context,
    NfcHistoryEntry entry,
    ValueChanged<NfcHistoryEntry> onReopen,
  ) {
    final luma = context.luma;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: luma.surface,
        title: Text(
          entry.direction == NfcHistoryDirection.written ? 'Written tag' : 'Scanned tag',
          style: TextStyle(color: luma.textPrimary, fontSize: 16),
        ),
        content: SizedBox(
          width: 360,
          child: entry.records.isEmpty
              ? Text('No records.', style: TextStyle(color: luma.textMuted))
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final record in entry.records)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                nfcRecordKindMeta(record.kind).icon,
                                color: nfcRecordKindMeta(record.kind).color,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  nfcRecordSummary(record),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: luma.textPrimary, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: TextStyle(color: luma.textSecondary)),
          ),
          if (entry.records.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                onReopen(entry);
              },
              child: Text('Load into editor', style: TextStyle(color: luma.accent)),
            ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.onTap, required this.onDelete});
  final NfcHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final written = entry.direction == NfcHistoryDirection.written;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: LumaCard(
          child: Row(
            children: [
              LumaIconBadge(
                icon: written ? Icons.upload_rounded : Icons.download_rounded,
                color: written ? luma.accent : luma.success,
                size: 40,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${written ? 'Written' : 'Scanned'} · ${entry.techLabel ?? 'NFC tag'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _relativeTime(entry.timestamp) +
                          (entry.records.isEmpty
                              ? ''
                              : ' · ${entry.records.length} record'
                                  '${entry.records.length == 1 ? '' : 's'}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (entry.locked)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.lock_rounded, color: luma.textMuted, size: 16),
                ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline_rounded, color: luma.textMuted, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
}
