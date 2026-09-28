import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import '../text_library_models.dart';
import '../text_library_repository.dart';
import '../text_library_scope.dart';
import 'format_toolbar.dart';
import 'rich_text_controller.dart';

/// Writes one text. Saves itself a moment after every change, so there is no
/// way to lose work by navigating away.
class TextEditorView extends StatefulWidget {
  const TextEditorView({
    super.key,
    required this.subjectId,
    this.text,
    required this.onClose,
  });

  final int subjectId;

  /// Null while writing a new text; it is created on the first real edit.
  final LibraryText? text;
  final VoidCallback onClose;

  @override
  State<TextEditorView> createState() => _TextEditorViewState();
}

enum _SaveState { idle, saving, saved }

class _TextEditorViewState extends State<TextEditorView> {
  late final RichTextController _body = RichTextController(widget.text?.body);
  late final TextEditingController _title = TextEditingController(
    text: widget.text?.title ?? '',
  );
  late final TextEditingController _spine = TextEditingController(
    text: widget.text?.spine ?? '',
  );
  late DyeColor _cover = widget.text?.cover ?? DyeColor.brown;
  late int? _id = widget.text?.id;
  late int _subjectId = widget.subjectId;
  final _bodyFocus = FocusNode();

  Timer? _debounce;
  Future<void>? _inFlight;
  bool _dirty = false;
  _SaveState _state = _SaveState.idle;
  late String _lastBody = _body.doc.encode();

  @override
  void initState() {
    super.initState();
    _body.addListener(_bodyChanged);
    _title.addListener(_markDirty);
    _spine.addListener(_markDirty);
    if (widget.text == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bodyFocus.requestFocus();
      });
    }
  }

  late TextLibraryRepository _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kept so a save can still run after this element has gone.
    _repository = TextLibraryScope.of(context);
  }

  void _bodyChanged() {
    // The controller also notifies for caret moves; only content counts.
    final encoded = _body.doc.encode();
    if (encoded == _lastBody) return;
    _lastBody = encoded;
    _markDirty();
  }

  void _markDirty() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<void> _save() async {
    _debounce?.cancel();
    if (!_dirty) return _inFlight;
    await _inFlight;
    if (!_dirty) return;
    final body = _body.doc;
    if (_id == null && body.isBlank && _title.text.trim().isEmpty) return;
    _dirty = false;
    if (mounted) setState(() => _state = _SaveState.saving);
    final future = _repository
        .saveText(
          id: _id,
          subjectId: _subjectId,
          title: _title.text,
          spine: _spine.text,
          body: body,
          cover: _cover,
        )
        .then((id) => _id = id);
    _inFlight = future;
    await future;
    if (mounted) setState(() => _state = _SaveState.saved);
  }

  Future<void> _close() async {
    await _save();
    widget.onClose();
  }

  Future<void> _delete() async {
    final t = L.of(context);
    final id = _id;
    if (id == null) {
      _dirty = false;
      widget.onClose();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.textLibraryDeleteTextTitle(_title.text.trim())),
        content: Text(t.textLibraryDeleteTextBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.textLibraryCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.luma.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.textLibraryDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _debounce?.cancel();
    _dirty = false;
    await _inFlight;
    if (!mounted) return;
    await _repository.deleteText(id);
    widget.onClose();
  }

  Future<void> _moveTo() async {
    final t = L.of(context);
    final repository = _repository;
    final subjects = await repository.watchSubjects().first;
    if (!mounted) return;
    final target = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(t.textLibraryMoveToTitle),
        children: [
          for (final subject in subjects)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, subject.id),
              child: Row(
                children: [
                  _Dot(color: subject.color.color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(subject.name)),
                  if (subject.id == _subjectId)
                    Icon(Icons.check_rounded, color: context.luma.accent),
                ],
              ),
            ),
        ],
      ),
    );
    if (target == null || target == _subjectId) return;
    _dirty = true;
    await _save();
    final id = _id;
    if (id == null) {
      setState(() => _subjectId = target);
      return;
    }
    final library = await repository.loadLibrary();
    final slot = firstFreeSlot(library.textsOf(target).map((t) => t.slot));
    await repository.moveText(id, subjectId: target, slot: slot);
    if (mounted) setState(() => _subjectId = target);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_dirty) {
      // Leaving mid-debounce (switching plugins, closing the window): write
      // what is there rather than drop it.
      unawaited(_flushOnDispose());
    }
    _body.dispose();
    _title.dispose();
    _spine.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  Future<void> _flushOnDispose() async {
    final body = _body.doc;
    if (_id == null && body.isBlank && _title.text.trim().isEmpty) return;
    await _inFlight;
    await _repository.saveText(
      id: _id,
      subjectId: _subjectId,
      title: _title.text,
      spine: _spine.text,
      body: body,
      cover: _cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final narrow = context.isPhoneWidth;
    final updated = widget.text?.updatedAt;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _body.toggleBold,
        const SingleActivator(LogicalKeyboardKey.keyI, control: true):
            _body.toggleItalic,
        const SingleActivator(LogicalKeyboardKey.keyU, control: true):
            _body.toggleUnderline,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            narrow ? 12 : 24,
            8,
            narrow ? 12 : 24,
            12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: t.textLibraryBack,
                    onPressed: _close,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _title,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: t.textLibraryTitleHint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _bodyFocus.requestFocus(),
                    ),
                  ),
                  _SaveIndicator(state: _state),
                  PopupMenuButton<String>(
                    tooltip: '',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (value) => switch (value) {
                      'move' => _moveTo(),
                      'delete' => _delete(),
                      _ => null,
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'move',
                        child: ListTile(
                          leading: const Icon(Icons.drive_file_move_rounded),
                          title: Text(t.textLibraryMoveTo),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline_rounded,
                            color: luma.danger,
                          ),
                          title: Text(
                            t.textLibraryDelete,
                            style: TextStyle(color: luma.danger),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (updated != null)
                Padding(
                  padding: const EdgeInsets.only(left: 52, bottom: 8),
                  child: Text(
                    t.textLibraryEdited(
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).add_Hm().format(updated),
                    ),
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FormatToolbar(controller: _body),
                  SizedBox(
                    width: narrow ? double.infinity : 260,
                    child: TextField(
                      controller: _spine,
                      maxLength: 40,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: t.textLibrarySpineLabel,
                        helperText: t.textLibrarySpineHint,
                        counterText: '',
                        prefixIcon: const Icon(
                          Icons.label_outline_rounded,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  _CoverButton(
                    cover: _cover,
                    onChanged: (dye) {
                      setState(() => _cover = dye);
                      _markDirty();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: luma.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: luma.border),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      // Keeps long-form lines at a readable measure.
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: TextField(
                        controller: _body,
                        focusNode: _bodyFocus,
                        maxLines: null,
                        expands: true,
                        keyboardType: TextInputType.multiline,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 16,
                          height: 1.6,
                        ),
                        decoration: InputDecoration(
                          hintText: t.textLibraryBodyHint,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isCollapsed: true,
                        ),
                      ),
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

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.state});

  final _SaveState state;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    final label = switch (state) {
      _SaveState.idle => '',
      _SaveState.saving => t.textLibrarySaving,
      _SaveState.saved => t.textLibrarySaved,
    };
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Row(
          key: ValueKey(state),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state == _SaveState.saved)
              Icon(Icons.check_rounded, size: 16, color: luma.success),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: luma.textMuted, fontSize: 12),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoverButton extends StatelessWidget {
  const _CoverButton({required this.cover, required this.onChanged});

  final DyeColor cover;
  final ValueChanged<DyeColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = L.of(context);
    final luma = context.luma;
    return MenuAnchor(
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
        backgroundColor: WidgetStatePropertyAll(luma.surface),
      ),
      menuChildren: [
        SizedBox(
          width: 4 * 40 + 3 * 6,
          child: DyePicker(value: cover, onChanged: onChanged),
        ),
      ],
      builder: (context, menu, _) => OutlinedButton.icon(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
        icon: _Dot(color: cover.color, size: 16),
        label: Text(t.textLibraryCover),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.size = 12});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: context.luma.border),
    ),
  );
}
