import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/luma_theme.dart';
import 'gallery_cache.dart';
import 'gallery_categories.dart';
import 'gallery_file_editor.dart';
import 'gallery_media.dart';
import 'gallery_repository.dart';
import 'gallery_smart.dart';
import 'gallery_tile.dart';

/// The details drawer behind the ⋮ button in the viewer: everything the
/// gallery knows about one file, and — behind the pencil — the two things it
/// is safe to change.
///
/// Design notes, following the loaded UI/UX rules:
///  * §6 `number-tabular` — every measured value is set in tabular figures so
///    the column doesn't jitter as you arrow through photos.
///  * §6 `truncation-strategy` — the folder path wraps rather than being cut
///    off, and can be copied; a path you can't read is no use.
///  * §8 `input-labels`, `error-placement` — edit fields carry visible labels
///    with the error directly underneath, never a placeholder standing in.
///  * §8 `sheet-dismiss-confirm` — closing with unsaved changes asks first.
///  * §4 `primary-action` — one primary button (Save); Cancel is subordinate.
class GalleryDetailsPanel extends StatefulWidget {
  const GalleryDetailsPanel({
    super.key,
    required this.item,
    required this.repository,
    required this.onClose,
    required this.onEdited,
  });

  final GalleryItem item;
  final GalleryRepository repository;
  final VoidCallback onClose;
  final ValueChanged<GalleryItem> onEdited;

  /// How wide the drawer sits on a desktop window.
  static const width = 340.0;

  @override
  State<GalleryDetailsPanel> createState() => _GalleryDetailsPanelState();
}

class _GalleryDetailsPanelState extends State<GalleryDetailsPanel> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  bool _editing = false;
  bool _saving = false;
  String? _nameError;
  String? _saveError;
  DateTime? _takenAt;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      // §8 inline-validation: check on blur, not on every keystroke.
      if (!_nameFocus.hasFocus && _editing) _validateName();
    });
  }

  @override
  void didUpdateWidget(GalleryDetailsPanel old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id && _editing) _stopEditing();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _dirty =>
      _editing &&
      (_nameController.text.trim() != widget.item.name ||
          (_takenAt != null && _takenAt != widget.item.takenAt));

  void _startEditing() {
    setState(() {
      _editing = true;
      _saveError = null;
      _nameError = null;
      _nameController.text = widget.item.name;
      _takenAt = widget.item.takenAt;
    });
  }

  void _stopEditing() {
    setState(() {
      _editing = false;
      _nameError = null;
      _saveError = null;
    });
  }

  void _validateName() {
    setState(() {
      _nameError = GalleryFileEditor.validateName(
        _nameController.text,
        originalName: widget.item.name,
      );
    });
  }

  /// §8 sheet-dismiss-confirm — never drop typed changes silently.
  Future<void> _requestClose() async {
    if (!_dirty) {
      widget.onClose();
      return;
    }
    final t = L.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.galleryDetailsDiscardTitle),
        content: Text(t.galleryDetailsDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.galleryDetailsKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.galleryDetailsDiscard),
          ),
        ],
      ),
    );
    if (discard == true) {
      _stopEditing();
      widget.onClose();
    }
  }

  Future<void> _pickDate() async {
    final current = _takenAt ?? widget.item.takenAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1826),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted) return;
    setState(() {
      _takenAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? current.hour,
        time?.minute ?? current.minute,
      );
    });
  }

  Future<void> _save() async {
    _validateName();
    if (_nameError != null) {
      // §8 focus-management: put the cursor back on what needs fixing.
      _nameFocus.requestFocus();
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final result = await widget.repository.editFile(
      widget.item,
      newName: _nameController.text.trim(),
      newTakenAt: _takenAt,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.ok) {
      setState(() => _saveError = result.error);
      return;
    }
    widget.onEdited(result.item!);
    _stopEditing();
    // §8 success-feedback.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L.of(context).commonSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final item = widget.item;

    return Container(
      width: GalleryDetailsPanel.width,
      decoration: BoxDecoration(
        color: luma.surface,
        border: Border(left: BorderSide(color: luma.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(luma),
            Divider(height: 1, color: luma.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: _editing ? _editFields(luma) : _readOnly(luma, item),
              ),
            ),
            if (_editing) _editActions(luma),
          ],
        ),
      ),
    );
  }

  Widget _header(LumaPalette luma) {
    final t = L.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _editing ? t.galleryDetailsEditTitle : t.commonDetails,
              style: TextStyle(
                color: luma.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!_editing)
            IconButton(
              // §1 aria-labels: an icon-only control needs a name.
              tooltip: widget.repository.canEditFiles
                  ? t.galleryDetailsEditTooltip
                  : t.galleryDetailsEditDisabled,
              onPressed:
                  widget.repository.canEditFiles ? _startEditing : null,
              icon: Icon(
                Icons.edit_outlined,
                size: 18,
                color: widget.repository.canEditFiles
                    ? luma.textSecondary
                    : luma.textMuted,
              ),
            ),
          IconButton(
            tooltip: t.galleryDetailsCloseTooltip,
            onPressed: _requestClose,
            icon: Icon(Icons.close_rounded, size: 18, color: luma.textSecondary),
          ),
        ],
      ),
    );
  }

  List<Widget> _readOnly(LumaPalette luma, GalleryItem item) {
    final t = L.of(context);
    final entry = widget.repository.cacheEntries[item.cacheKey];
    final format = GalleryFileEditor.extensionOf(item.name).toUpperCase();

    return [
      Text(
        item.name,
        style: TextStyle(
          color: luma.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 16),
      _Section(label: t.galleryDetailsSectionFile, luma: luma),
      _Row(
        label: t.galleryDetailsFormat,
        value: format.isEmpty ? t.commonUnknown : format,
        luma: luma,
      ),
      _SizeRow(item: item, repository: widget.repository, luma: luma),
      if (item.cloudOnly)
        _Row(
          label: t.galleryDetailsStored,
          value: t.galleryDetailsOnlineOnly,
          luma: luma,
        ),
      _PathRow(item: item, luma: luma),
      const SizedBox(height: 18),
      _Section(label: t.galleryDetailsSectionPicture, luma: luma),
      _Row(
        label: t.galleryDetailsTaken,
        value: _formatDateTime(t, item.takenAt),
        luma: luma,
      ),
      if (item.width > 0 && item.height > 0)
        _Row(
          label: t.galleryDetailsDimensions,
          value: '${item.width} × ${item.height}',
          luma: luma,
        ),
      if (item.isVideo)
        _Row(
          label: t.galleryDetailsLength,
          value: formatDuration(item.duration),
          luma: luma,
        ),
      if (item.hasLocation)
        _Row(
          label: t.galleryDetailsLocation,
          value: '${item.latitude!.toStringAsFixed(5)}, '
              '${item.longitude!.toStringAsFixed(5)}',
          luma: luma,
        ),
      if (_smartLabels(t, entry).isNotEmpty) ...[
        const SizedBox(height: 18),
        _Section(label: t.galleryDetailsSectionRecognised, luma: luma),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final label in _smartLabels(t, entry))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: luma.accent, fontSize: 11),
                ),
              ),
          ],
        ),
      ],
    ];
  }

  List<String> _smartLabels(L t, GalleryCacheEntry? entry) {
    if (entry == null) return const [];
    final buckets = <String>{
      for (final label in entry.labels)
        if (bucketForLabel(label) != null) bucketForLabel(label)!,
    };
    return [
      if (entry.faceCount > 0) t.galleryDetailsFaces(entry.faceCount),
      for (final bucket in buckets) galleryBucketName(t, bucket),
    ];
  }

  List<Widget> _editFields(LumaPalette luma) {
    final t = L.of(context);
    return [
        _FieldLabel(text: t.galleryDetailsFileName, luma: luma),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          autofocus: true,
          enabled: !_saving,
          style: TextStyle(color: luma.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: luma.background,
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
              borderSide: BorderSide(color: luma.accent, width: 2),
            ),
            errorText: _nameError,
            errorMaxLines: 3,
          ),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 6),
        Text(
          t.galleryDetailsKeepExtension(
            GalleryFileEditor.extensionOf(widget.item.name),
          ),
          style: TextStyle(color: luma.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 18),
        _FieldLabel(text: t.galleryDetailsDateTaken, luma: luma),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _saving ? null : _pickDate,
          icon: Icon(Icons.event_rounded, size: 16, color: luma.textSecondary),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _formatDateTime(t, _takenAt ?? widget.item.takenAt),
              style: TextStyle(color: luma.textPrimary, fontSize: 13),
            ),
          ),
          style: OutlinedButton.styleFrom(
            // §2 touch-target-size.
            minimumSize: const Size.fromHeight(44),
            alignment: Alignment.centerLeft,
            side: BorderSide(color: luma.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t.galleryDetailsDateNote,
          style: TextStyle(color: luma.textMuted, fontSize: 11),
        ),
        if (_saveError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: luma.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 16, color: luma.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _saveError!,
                    style: TextStyle(color: luma.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
    ];
  }

  Widget _editActions(LumaPalette luma) {
    final t = L.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: LumaGhostButton(
              label: t.commonCancel,
              onTap: _saving ? () {} : _stopEditing,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LumaPrimaryButton(
              label: _saving ? t.galleryDetailsSaving : t.commonSave,
              icon: Icons.check_rounded,
              onTap: _saving ? () {} : _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.luma});
  final String label;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: luma.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.luma});
  final String text;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: luma.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
}

/// A label/value pair. Values use tabular figures so numbers line up and
/// don't shift as the viewer moves between photos.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.luma});
  final String label;
  final String value;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );
}

/// Size on disk, looked up when the panel opens rather than during the scan.
class _SizeRow extends StatelessWidget {
  const _SizeRow({
    required this.item,
    required this.repository,
    required this.luma,
  });

  final GalleryItem item;
  final GalleryRepository repository;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    return FutureBuilder<int?>(
      future: repository.fileSize(item),
      initialData: item.sizeBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return _Row(
          label: t.commonSize,
          value: bytes == null ? '—' : formatBytes(bytes),
          luma: luma,
        );
      },
    );
  }
}

/// The folder the file sits in. Wrapped rather than truncated — a path you
/// can only see half of answers nothing — and copyable.
class _PathRow extends StatelessWidget {
  const _PathRow({required this.item, required this.luma});

  final GalleryItem item;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final full = item.path ?? item.id;
    final separator = full.contains(r'\') ? r'\' : '/';
    final cut = full.lastIndexOf(separator);
    final directory = cut <= 0 ? item.folder : full.substring(0, cut);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                child: Text(
                  t.galleryDetailsFolder,
                  style: TextStyle(color: luma.textMuted, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: t.galleryDetailsCopyPath,
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: directory));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.galleryDetailsPathCopied)),
                  );
                },
                icon: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: luma.textSecondary,
                ),
              ),
            ],
          ),
          SelectableText(
            directory,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(L t, DateTime when) {
  String two(int value) => value.toString().padLeft(2, '0');
  return t.galleryDetailsDateTime(
    when.day,
    galleryMonthShort(t, when.month),
    when.year,
    '${two(when.hour)}:${two(when.minute)}',
  );
}

/// Whether this build can rename files at all. The desktop sources work in
/// real directories; MediaStore hands out ids and needs a different call
/// altogether, so the phone shows the pencil disabled rather than failing
/// halfway through a rename.
bool get galleryEditingSupported =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
