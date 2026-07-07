import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../theme/luma_theme.dart';
import '../data/school_database.dart';
import '../logic/spaced_repetition.dart';
import '../school_repository.dart';
import '../school_scope.dart';

/// Flashcard decks, card management, and an SM-2 spaced-repetition review
/// session.
class FlashcardsTab extends StatefulWidget {
  const FlashcardsTab({super.key});

  @override
  State<FlashcardsTab> createState() => _FlashcardsTabState();
}

class _FlashcardsTabState extends State<FlashcardsTab> {
  int? _activeDeckId;

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _activeDeckId == null
          ? _DeckListView(
              key: const ValueKey('list'),
              onOpen: (id) => setState(() => _activeDeckId = id),
            )
          : _DeckDetailView(
              key: ValueKey('deck-$_activeDeckId'),
              deckId: _activeDeckId!,
              repo: repo,
              onClose: () => setState(() => _activeDeckId = null),
            ),
    );
  }
}

class _DeckListView extends StatefulWidget {
  const _DeckListView({super.key, required this.onOpen});
  final ValueChanged<int> onOpen;

  @override
  State<_DeckListView> createState() => _DeckListViewState();
}

class _DeckListViewState extends State<_DeckListView> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create(SchoolRepository repo) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final id = await repo.createDeck(name);
    _nameController.clear();
    if (mounted) widget.onOpen(id);
  }

  @override
  Widget build(BuildContext context) {
    final repo = SchoolScope.of(context);
    final luma = context.luma;
    return StreamData<List<FlashcardDeck>>(
      stream: repo.watchDecks(),
      builder: (context, decks) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'New deck name',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _create(repo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  LumaPrimaryButton(
                    label: 'Create deck',
                    icon: Icons.add_rounded,
                    onTap: () => _create(repo),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: decks.isEmpty
                    ? const LumaEmptyState(
                        icon: Icons.style_rounded,
                        title: 'No decks yet',
                        subtitle: 'Create a deck, then add cards to start studying.',
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisExtent: 100,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: decks.length,
                        itemBuilder: (context, i) {
                          final d = decks[i];
                          return StreamData<List<Flashcard>>(
                            stream: repo.watchCards(d.id),
                            builder: (context, cards) {
                              final due = cards
                                  .where((c) => !c.nextReviewDate.isAfter(DateTime.now()))
                                  .length;
                              return LumaCard(
                                child: InkWell(
                                  onTap: () => widget.onOpen(d.id),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.name,
                                          style: TextStyle(
                                              color: luma.textPrimary, fontWeight: FontWeight.w700)),
                                      const Spacer(),
                                      Text('${cards.length} cards',
                                          style: TextStyle(color: luma.textMuted, fontSize: 12)),
                                      if (due > 0)
                                        Text('$due due now',
                                            style: TextStyle(
                                                color: luma.accent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeckDetailView extends StatefulWidget {
  const _DeckDetailView({
    super.key,
    required this.deckId,
    required this.repo,
    required this.onClose,
  });
  final int deckId;
  final SchoolRepository repo;
  final VoidCallback onClose;

  @override
  State<_DeckDetailView> createState() => _DeckDetailViewState();
}

class _DeckDetailViewState extends State<_DeckDetailView> {
  bool _studying = false;

  @override
  Widget build(BuildContext context) {
    return StreamData<List<Flashcard>>(
      stream: widget.repo.watchCards(widget.deckId),
      builder: (context, cards) {
        final due = cards.where((c) => !c.nextReviewDate.isAfter(DateTime.now())).toList();
        if (_studying) {
          if (due.isEmpty) {
            _studying = false;
          } else {
            return _StudySession(
              repo: widget.repo,
              cards: due,
              onDone: () => setState(() => _studying = false),
            );
          }
        }
        return _ManageCardsView(
          deckId: widget.deckId,
          repo: widget.repo,
          cards: cards,
          dueCount: due.length,
          onClose: widget.onClose,
          onStudy: due.isEmpty ? null : () => setState(() => _studying = true),
        );
      },
    );
  }
}

class _ManageCardsView extends StatefulWidget {
  const _ManageCardsView({
    required this.deckId,
    required this.repo,
    required this.cards,
    required this.dueCount,
    required this.onClose,
    required this.onStudy,
  });
  final int deckId;
  final SchoolRepository repo;
  final List<Flashcard> cards;
  final int dueCount;
  final VoidCallback onClose;
  final VoidCallback? onStudy;

  @override
  State<_ManageCardsView> createState() => _ManageCardsViewState();
}

class _ManageCardsViewState extends State<_ManageCardsView> {
  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onClose,
              ),
              Expanded(
                child: Text('${widget.cards.length} cards · ${widget.dueCount} due',
                    style: TextStyle(color: luma.textSecondary)),
              ),
              LumaGhostButton(
                label: 'Add card',
                icon: Icons.add_rounded,
                onTap: () => _openEditor(context),
              ),
              const SizedBox(width: 10),
              LumaPrimaryButton(
                label: 'Study now',
                icon: Icons.play_arrow_rounded,
                onTap: widget.onStudy,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: widget.cards.isEmpty
                ? const LumaEmptyState(
                    icon: Icons.style_outlined,
                    title: 'No cards in this deck',
                    subtitle: 'Add a front/back card to start reviewing.',
                  )
                : ListView.separated(
                    itemCount: widget.cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = widget.cards[i];
                      return LumaCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.front,
                                      style: TextStyle(
                                          color: luma.textPrimary, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(c.back, style: TextStyle(color: luma.textMuted, fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _openEditor(context, existing: c),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: luma.textMuted, size: 20),
                              onPressed: () => widget.repo.deleteCard(c.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {Flashcard? existing}) {
    return showDialog(
      context: context,
      builder: (_) => _CardDialog(deckId: widget.deckId, repo: widget.repo, existing: existing),
    );
  }
}

class _CardDialog extends StatefulWidget {
  const _CardDialog({required this.deckId, required this.repo, this.existing});
  final int deckId;
  final SchoolRepository repo;
  final Flashcard? existing;

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  late final _frontController = TextEditingController(text: widget.existing?.front ?? '');
  late final _backController = TextEditingController(text: widget.existing?.back ?? '');

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final front = _frontController.text.trim();
    final back = _backController.text.trim();
    if (front.isEmpty || back.isEmpty) return;
    if (widget.existing == null) {
      await widget.repo.createCard(widget.deckId, front, back);
    } else {
      await widget.repo.updateCard(widget.existing!.id, front: front, back: back);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add card' : 'Edit card'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _frontController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Front'),
            maxLines: 2,
          ),
          TextField(
            controller: _backController,
            decoration: const InputDecoration(labelText: 'Back'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _StudySession extends StatefulWidget {
  const _StudySession({required this.repo, required this.cards, required this.onDone});
  final SchoolRepository repo;
  final List<Flashcard> cards;
  final VoidCallback onDone;

  @override
  State<_StudySession> createState() => _StudySessionState();
}

class _StudySessionState extends State<_StudySession> {
  int _index = 0;
  bool _revealed = false;

  Future<void> _rate(ReviewRating rating) async {
    await widget.repo.reviewCard(widget.cards[_index], rating);
    if (_index + 1 >= widget.cards.length) {
      widget.onDone();
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final card = widget.cards[_index];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Card ${_index + 1} of ${widget.cards.length}',
              style: TextStyle(color: luma.textMuted)),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _revealed = !_revealed),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: LumaCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(card.front,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: luma.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                        if (_revealed) ...[
                          Divider(color: luma.border, height: 32),
                          Text(card.back,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: luma.textSecondary, fontSize: 16)),
                        ] else ...[
                          const SizedBox(height: 16),
                          Text('Tap to reveal answer',
                              style: TextStyle(color: luma.textMuted, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_revealed)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RatingButton(label: 'Again', color: luma.danger, onTap: () => _rate(ReviewRating.again)),
                const SizedBox(width: 10),
                _RatingButton(label: 'Hard', color: const Color(0xFFFFB020), onTap: () => _rate(ReviewRating.hard)),
                const SizedBox(width: 10),
                _RatingButton(label: 'Good', color: luma.accent, onTap: () => _rate(ReviewRating.good)),
                const SizedBox(width: 10),
                _RatingButton(label: 'Easy', color: luma.success, onTap: () => _rate(ReviewRating.easy)),
              ],
            )
          else
            LumaGhostButton(label: 'End session', onTap: widget.onDone),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
      child: Text(label),
    );
  }
}
