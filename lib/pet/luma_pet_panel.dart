import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/window_controls.dart';
import '../l10n/app_localizations.dart';
import '../theme/luma_theme.dart';
import 'pet_repository.dart';
import 'pet_scope.dart';
import 'pet_search.dart';
import 'pet_sprite.dart';

/// The panel's logical size. On desktop the window is shrunk to exactly this
/// (see `kPetWindowSize`) so the card fills it edge to edge; everywhere else
/// it floats over the app at the same size.
const Size kPetPanelSize = Size(480, 556);

/// Row height, kept above the 44px touch minimum so the same list works under
/// a finger on a phone.
const double _rowHeight = 48;

/// The luma pet: a small summonable panel that searches everything the app
/// can open and takes you there.
///
/// Keyboard-first, in the shape people already know from Spotlight and
/// Raycast — type to filter, arrows to move, Enter to open, Escape to
/// dismiss — with every one of those also reachable by mouse or touch.
class LumaPetPanel extends StatefulWidget {
  const LumaPetPanel({
    super.key,
    required this.targets,
    required this.fullBleed,
  });

  /// Everything the pet can open, built by the shell.
  final List<PetTarget> targets;

  /// True when the panel *is* the window (desktop), so it paints square to
  /// the edges with no scrim behind it.
  final bool fullBleed;

  @override
  State<LumaPetPanel> createState() => _LumaPetPanelState();
}

class _LumaPetPanelState extends State<LumaPetPanel> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _fieldFocus = FocusNode();
  final ScrollController _scroll = ScrollController();

  int _selected = 0;
  List<PetTarget> _results = const [];

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    _query.dispose();
    _fieldFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    PetScope.read(context).setQuery(_query.text);
    setState(() => _selected = 0);
  }

  void _move(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      // Wraps, so holding Down walks the list round rather than sticking.
      _selected = (_selected + delta) % _results.length;
      if (_selected < 0) _selected += _results.length;
    });
    _scrollSelectedIntoView();
  }

  void _scrollSelectedIntoView() {
    if (!_scroll.hasClients) return;
    final top = _selected * _rowHeight;
    final bottom = top + _rowHeight;
    final view = _scroll.position;
    if (top < view.pixels) {
      _scroll.jumpTo(top.clamp(0.0, view.maxScrollExtent));
    } else if (bottom > view.pixels + view.viewportDimension) {
      _scroll.jumpTo(
        (bottom - view.viewportDimension).clamp(0.0, view.maxScrollExtent),
      );
    }
  }

  Future<void> _openSelected() async {
    if (_selected < 0 || _selected >= _results.length) return;
    await _open(_results[_selected]);
  }

  Future<void> _open(PetTarget target) async {
    final pet = PetScope.read(context);
    await pet.recordOpen(target.id);
    // Close first: on desktop this puts the window back to full size, so the
    // page the user asked for is laid out for the real window, not the panel.
    await pet.close(navigating: true);
    target.open();
  }

  Future<void> _dismiss() => PetScope.read(context).close();

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final pet = PetScope.of(context);
    _results = rankPetTargets(
      widget.targets,
      _query.text,
      recentIds: pet.recentIds,
    );
    // The list just got shorter under the cursor (a keystroke filtered it):
    // fall back to the best match rather than pointing past the end.
    if (_selected >= _results.length) _selected = 0;

    final card = _card(context, luma, pet);

    if (widget.fullBleed) return card;

    // Layered over the running app: a scrim dark enough to isolate the panel,
    // and a tap anywhere outside it dismisses.
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.48)),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: kPetPanelSize.width,
                    maxHeight: kPetPanelSize.height,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: card,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(BuildContext context, LumaPalette luma, PetRepository pet) {
    final t = L.of(context);
    return Shortcuts(
      // Sits between the text field and Flutter's own text-editing shortcuts,
      // so these win over "move the caret" for the arrow keys.
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowUp): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.tab): _MoveIntent(1),
        SingleActivator(LogicalKeyboardKey.tab, shift: true): _MoveIntent(-1),
        SingleActivator(LogicalKeyboardKey.enter): _OpenSelectedIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _OpenSelectedIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _DismissPetIntent(),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (intent) {
              _move(intent.delta);
              return null;
            },
          ),
          _OpenSelectedIntent: CallbackAction<_OpenSelectedIntent>(
            onInvoke: (_) {
              _openSelected();
              return null;
            },
          ),
          _DismissPetIntent: CallbackAction<_DismissPetIntent>(
            onInvoke: (_) {
              _dismiss();
              return null;
            },
          ),
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: luma.surface,
            border: Border.all(color: luma.border),
            borderRadius: widget.fullBleed ? null : BorderRadius.circular(20),
            boxShadow: widget.fullBleed
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          child: Column(
            children: [
              _header(context, luma, pet, t),
              _searchField(luma, t),
              Expanded(child: _resultList(luma, t)),
              _footer(luma, pet, t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    LumaPalette luma,
    PetRepository pet,
    L t,
  ) {
    final mood = pet.mood;
    // In window mode the panel has no title bar of its own, so the header
    // doubles as the drag handle for the whole window.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: widget.fullBleed ? (_) => windowStartDrag() : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: luma.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: t.petPatLabel(pet.name),
              child: Tooltip(
                message: t.petPatLabel(pet.name),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: pet.pat,
                    child: PetSprite(
                      mood: mood,
                      patCount: pet.pats,
                      size: 76,
                      // Leans towards the search field while typing.
                      lookAt: mood == PetMood.curious
                          ? const Offset(0.6, 0.8)
                          : Offset.zero,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pet.name,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      _moodLine(t, mood),
                      key: ValueKey(mood),
                      style: TextStyle(
                        color: luma.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _dismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: luma.textMuted,
              tooltip: t.petClose,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            ),
          ],
        ),
      ),
    );
  }

  String _moodLine(L t, PetMood mood) => switch (mood) {
        PetMood.idle => t.petMoodIdle,
        PetMood.curious => t.petMoodCurious,
        PetMood.happy => t.petMoodHappy,
        PetMood.delighted => t.petMoodDelighted,
        PetMood.sleepy => t.petMoodSleepy,
      };

  Widget _searchField(LumaPalette luma, L t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: TextField(
        controller: _query,
        focusNode: _fieldFocus,
        autofocus: true,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _openSelected(),
        style: TextStyle(color: luma.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: t.petSearchHint,
          hintStyle: TextStyle(color: luma.textMuted, fontSize: 15),
          prefixIcon: Icon(Icons.search_rounded, color: luma.textMuted, size: 20),
          filled: true,
          fillColor: luma.background,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: luma.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: luma.accent, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _resultList(LumaPalette luma, L t) {
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, color: luma.textMuted, size: 28),
              const SizedBox(height: 10),
              Text(
                t.petNoResults,
                textAlign: TextAlign.center,
                style: TextStyle(color: luma.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                t.petNoResultsHint,
                textAlign: TextAlign.center,
                style: TextStyle(color: luma.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    final showingRecents = _query.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
          child: Text(
            showingRecents ? t.petSectionJumpTo : t.petSectionResults,
            style: TextStyle(
              color: luma.textMuted,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemExtent: _rowHeight,
            itemCount: _results.length,
            itemBuilder: (context, i) => _row(luma, t, _results[i], i),
          ),
        ),
      ],
    );
  }

  Widget _row(LumaPalette luma, L t, PetTarget target, int index) {
    final selected = index == _selected;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? luma.accentSubtle : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _open(target),
          // Hover moves the selection so the mouse and the arrow keys never
          // disagree about which row Enter would open.
          onHover: (hovering) {
            if (hovering && _selected != index) {
              setState(() => _selected = index);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  target.icon,
                  size: 19,
                  color: selected ? luma.accent : luma.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    target.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: luma.textPrimary,
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  target.kind == PetTargetKind.plugin
                      ? t.petKindPlugin
                      : t.petKindPage,
                  style: TextStyle(color: luma.textMuted, fontSize: 11.5),
                ),
                if (selected) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.keyboard_return_rounded,
                      size: 15, color: luma.accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(LumaPalette luma, PetRepository pet, L t) {
    final hintStyle = TextStyle(color: luma.textMuted, fontSize: 11.5);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: luma.background,
        border: Border(top: BorderSide(color: luma.border)),
        borderRadius: widget.fullBleed
            ? null
            : const BorderRadius.vertical(bottom: Radius.circular(19)),
      ),
      child: Row(
        children: [
          _key(luma, '↑↓'),
          const SizedBox(width: 6),
          Text(t.petHintMove, style: hintStyle),
          const SizedBox(width: 12),
          _key(luma, '⏎'),
          const SizedBox(width: 6),
          Text(t.petHintOpen, style: hintStyle),
          const SizedBox(width: 12),
          _key(luma, 'Esc'),
          const SizedBox(width: 6),
          Text(t.petHintClose, style: hintStyle),
          const Spacer(),
          Tooltip(
            message: t.petPatsTooltip,
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, size: 12, color: luma.accent),
                const SizedBox(width: 4),
                Text('${pet.pats}', style: hintStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _key(LumaPalette luma, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: luma.surface,
          border: Border.all(color: luma.border),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: luma.textSecondary,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
      );
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}

class _OpenSelectedIntent extends Intent {
  const _OpenSelectedIntent();
}

class _DismissPetIntent extends Intent {
  const _DismissPetIntent();
}
