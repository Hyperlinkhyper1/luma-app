import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'recipes_editor.dart';
import 'recipes_models.dart';
import 'recipes_repository.dart';
import 'recipes_widgets.dart';

// ---- Entry points ----------------------------------------------------------

Future<void> showLocalRecipeDetail(
  BuildContext context,
  RecipesController controller,
  LocalRecipe recipe,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _LocalRecipeDetail(controller: controller, recipe: recipe),
  );
}

Future<void> showPublicRecipeDetail(
  BuildContext context,
  RecipesController controller,
  PublicRecipe recipe,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => _PublicRecipeDetail(controller: controller, initial: recipe),
  );
}

// ---- Local recipe detail ---------------------------------------------------

class _LocalRecipeDetail extends StatefulWidget {
  const _LocalRecipeDetail({required this.controller, required this.recipe});
  final RecipesController controller;
  final LocalRecipe recipe;

  @override
  State<_LocalRecipeDetail> createState() => _LocalRecipeDetailState();
}

class _LocalRecipeDetailState extends State<_LocalRecipeDetail> {
  late int _servings;

  @override
  void initState() {
    super.initState();
    _servings = widget.recipe.servings;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final recipe = widget.controller.privateRecipes
                .where((r) => r.id == widget.recipe.id)
                .cast<LocalRecipe?>()
                .firstWhere((r) => true, orElse: () => null) ??
            widget.recipe;
        final scale = recipe.servings == 0 ? 1.0 : _servings / recipe.servings;
        return _DetailShell(
          hero: LocalRecipeImage(
              path: recipe.photoPath, category: recipe.category),
          heroOverlay: [
            _favoriteOverlay(
                active: recipe.isFavorite,
                onTap: () =>
                    widget.controller.toggleFavoriteLocal(recipe.id)),
          ],
          category: recipe.category,
          title: recipe.title,
          subtitle: recipe.isPublished ? 'Shared to Public' : 'Private recipe',
          subtitleIcon:
              recipe.isPublished ? Icons.public_rounded : Icons.lock_rounded,
          description: recipe.description,
          servings: _servings,
          onServings: (v) => setState(() => _servings = v),
          prepMinutes: recipe.prepMinutes,
          cookMinutes: recipe.cookMinutes,
          ingredients: recipe.ingredients,
          steps: recipe.steps,
          scale: scale,
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              LumaGhostButton(
                label: 'Delete',
                icon: Icons.delete_outline_rounded,
                onTap: () async {
                  final ok = await _confirmDelete(context, recipe.title);
                  if (ok == true) {
                    await widget.controller.deleteLocal(recipe.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
              const SizedBox(width: 10),
              LumaGhostButton(
                label: 'Edit',
                icon: Icons.edit_rounded,
                onTap: () {
                  Navigator.pop(context);
                  showRecipeEditor(context, widget.controller,
                      existing: recipe);
                },
              ),
            ],
          ),
          luma: luma,
        );
      },
    );
  }
}

// ---- Public recipe detail --------------------------------------------------

class _PublicRecipeDetail extends StatefulWidget {
  const _PublicRecipeDetail({required this.controller, required this.initial});
  final RecipesController controller;
  final PublicRecipe initial;

  @override
  State<_PublicRecipeDetail> createState() => _PublicRecipeDetailState();
}

class _PublicRecipeDetailState extends State<_PublicRecipeDetail> {
  late int _servings;

  @override
  void initState() {
    super.initState();
    _servings = widget.initial.servings;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    await widget.controller.loadRecipeDetail(widget.initial.id);
  }

  PublicRecipe get _current {
    for (final r in widget.controller.publicRecipes) {
      if (r.id == widget.initial.id) return r;
    }
    return widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final recipe = _current;
        final fav = widget.controller.isFavoritePublic(recipe.id);
        final scale = recipe.servings == 0 ? 1.0 : _servings / recipe.servings;
        return _DetailShell(
          hero: RemoteRecipeImage(
            controller: widget.controller,
            photoId: recipe.photoId,
            category: recipe.category,
          ),
          heroOverlay: [
            _favoriteOverlay(
                active: fav,
                onTap: () =>
                    widget.controller.toggleFavoritePublic(recipe.id)),
          ],
          category: recipe.category,
          title: recipe.title,
          subtitle: 'by ${recipe.authorName}${recipe.mine ? ' · you' : ''}',
          subtitleIcon: Icons.person_rounded,
          description: recipe.description,
          ratingHeader: _ratingHeader(luma, recipe),
          servings: _servings,
          onServings: (v) => setState(() => _servings = v),
          prepMinutes: recipe.prepMinutes,
          cookMinutes: recipe.cookMinutes,
          ingredients: recipe.ingredients,
          steps: recipe.steps,
          scale: scale,
          extraSections: [
            const SizedBox(height: 22),
            _reviewsSection(luma, recipe),
          ],
          footer: recipe.mine
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    LumaGhostButton(
                      label: 'Remove from Public',
                      icon: Icons.public_off_rounded,
                      onTap: () async {
                        final ok = await _confirmDelete(context, recipe.title,
                            action: 'Remove');
                        if (ok == true) {
                          final err = await widget.controller
                              .unpublishByPublicId(recipe.id);
                          if (context.mounted) {
                            Navigator.pop(context);
                            if (err != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err)));
                            }
                          }
                        }
                      },
                    ),
                  ],
                )
              : null,
          luma: luma,
        );
      },
    );
  }

  Widget _ratingHeader(LumaPalette luma, PublicRecipe recipe) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          RecipeStars(rating: recipe.ratingAvg, size: 18),
          const SizedBox(width: 8),
          Text(
            recipe.ratingCount == 0
                ? 'No ratings yet'
                : '${recipe.ratingAvg.toStringAsFixed(1)} · ${recipe.ratingCount} '
                    'rating${recipe.ratingCount == 1 ? '' : 's'}',
            style: TextStyle(
                color: luma.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _reviewsSection(LumaPalette luma, PublicRecipe recipe) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            label: 'Reviews (${recipe.reviews.length})',
            icon: Icons.reviews_rounded),
        const SizedBox(height: 12),
        _ReviewComposer(controller: widget.controller, recipe: recipe),
        const SizedBox(height: 16),
        if (recipe.reviews.isEmpty)
          Text('Be the first to review this recipe.',
              style: TextStyle(color: luma.textMuted, fontSize: 13))
        else
          ...recipe.reviews.map((r) => _ReviewTile(
                controller: widget.controller,
                review: r,
                category: recipe.category,
              )),
      ],
    );
  }
}

// ---- Review composer -------------------------------------------------------

class _ReviewComposer extends StatefulWidget {
  const _ReviewComposer({required this.controller, required this.recipe});
  final RecipesController controller;
  final PublicRecipe recipe;

  @override
  State<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<_ReviewComposer> {
  late final TextEditingController _text;
  int _rating = 0;
  Uint8List? _photo;
  bool _submitting = false;
  int _syncedForRating = -1;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController();
    _rating = widget.recipe.myRating ?? 0;
    _syncedForRating = widget.recipe.myRating ?? 0;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result =
        await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      try {
        bytes = await File(file.path!).readAsBytes();
      } catch (_) {}
    }
    if (bytes != null) setState(() => _photo = bytes);
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a star rating first.')));
      return;
    }
    setState(() => _submitting = true);
    final err = await widget.controller.submitReview(
      widget.recipe.id,
      rating: _rating,
      text: _text.text.trim(),
      photoBytes: _photo,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (err == null) _photo = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
        content: Text(err ?? 'Thanks for your review!')));
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    // Keep the star input in step if the server reports a different existing
    // rating after a refresh (but never stomp an in-progress edit).
    final serverRating = widget.recipe.myRating ?? 0;
    if (serverRating != _syncedForRating) {
      _syncedForRating = serverRating;
      _rating = serverRating;
    }
    final alreadyReviewed = widget.recipe.myRating != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alreadyReviewed ? 'Your review' : 'Write a review',
              style: TextStyle(
                  color: luma.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          InteractiveStars(
              value: _rating, onChanged: (v) => setState(() => _rating = v)),
          const SizedBox(height: 12),
          RecipeTextField(
            controller: _text,
            hint: 'Share how it turned out… (optional)',
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          if (_photo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    Image.memory(_photo!,
                        height: 120, width: double.infinity, fit: BoxFit.cover),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: GestureDetector(
                        onTap: () => setState(() => _photo = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              LumaGhostButton(
                label: _photo == null ? 'Add photo' : 'Change photo',
                icon: Icons.add_a_photo_outlined,
                onTap: _pickPhoto,
              ),
              const Spacer(),
              if (alreadyReviewed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: LumaGhostButton(
                    label: 'Delete',
                    onTap: () async {
                      final err = await widget.controller
                          .deleteMyReview(widget.recipe.id);
                      if (!mounted) return;
                      setState(() => _rating = 0);
                      if (err != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                  ),
                ),
              LumaPrimaryButton(
                label: alreadyReviewed ? 'Update' : 'Post review',
                icon: Icons.send_rounded,
                loading: _submitting,
                onTap: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.controller,
    required this.review,
    required this.category,
  });
  final RecipesController controller;
  final RecipeReview review;
  final String category;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final initial =
        review.authorName.isNotEmpty ? review.authorName[0].toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: luma.accentSubtle,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initial,
                      style: TextStyle(
                          color: luma.accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(review.mine ? 'You' : review.authorName,
                            style: TextStyle(
                                color: luma.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        RecipeStars(rating: review.rating.toDouble(), size: 13),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(_relativeDate(review.createdAtMs),
                        style: TextStyle(color: luma.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          if (review.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.text,
                style: TextStyle(
                    color: luma.textSecondary, fontSize: 13, height: 1.4)),
          ],
          if (review.photoId != null && review.photoId!.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openPhoto(context, controller, review.photoId!, category),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: RemoteRecipeImage(
                    controller: controller,
                    photoId: review.photoId,
                    category: category,
                    iconSize: 28,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Shared detail shell ---------------------------------------------------

class _DetailShell extends StatelessWidget {
  const _DetailShell({
    required this.hero,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.subtitleIcon,
    required this.servings,
    required this.onServings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.ingredients,
    required this.steps,
    required this.scale,
    required this.luma,
    this.heroOverlay = const [],
    this.description,
    this.ratingHeader,
    this.extraSections = const [],
    this.footer,
  });

  final Widget hero;
  final List<Widget> heroOverlay;
  final String category;
  final String title;
  final String subtitle;
  final IconData subtitleIcon;
  final String? description;
  final Widget? ratingHeader;
  final int servings;
  final ValueChanged<int> onServings;
  final int prepMinutes;
  final int cookMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final double scale;
  final List<Widget> extraSections;
  final Widget? footer;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    final prepStr = formatRecipeTime(prepMinutes);
    final cookStr = formatRecipeTime(cookMinutes);
    return Dialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: luma.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(height: 200, width: double.infinity, child: hero),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: RecipeCategoryTag(category: category),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Row(children: [
                    ...heroOverlay,
                    const SizedBox(width: 8),
                    _circleButton(Icons.close_rounded,
                        () => Navigator.pop(context)),
                  ]),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: luma.textPrimary,
                            fontSize: 23,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(subtitleIcon, size: 14, color: luma.textMuted),
                        const SizedBox(width: 6),
                        Text(subtitle,
                            style:
                                TextStyle(color: luma.textMuted, fontSize: 12)),
                      ],
                    ),
                    if (description != null && description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(description!,
                          style: TextStyle(
                              color: luma.textSecondary,
                              fontSize: 13,
                              height: 1.4)),
                    ],
                    if (ratingHeader != null) ratingHeader!,
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _StatChip(
                          icon: Icons.people_outline_rounded,
                          label: '$servings serving${servings == 1 ? '' : 's'}',
                          luma: luma,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SmallIconButton(
                                  icon: Icons.remove_rounded,
                                  luma: luma,
                                  onTap: servings > 1
                                      ? () => onServings(servings - 1)
                                      : null),
                              const SizedBox(width: 4),
                              _SmallIconButton(
                                  icon: Icons.add_rounded,
                                  luma: luma,
                                  onTap: () => onServings(servings + 1)),
                            ],
                          ),
                        ),
                        if (prepStr.isNotEmpty)
                          _StatChip(
                              icon: Icons.timer_outlined,
                              label: 'Prep: $prepStr',
                              luma: luma),
                        if (cookStr.isNotEmpty)
                          _StatChip(
                              icon: Icons.local_fire_department_outlined,
                              label: 'Cook: $cookStr',
                              luma: luma),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (ingredients.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Ingredients',
                          icon: Icons.format_list_bulleted_rounded),
                      const SizedBox(height: 10),
                      ...ingredients.map((ing) =>
                          _IngredientRow(ingredient: ing, scale: scale, luma: luma)),
                      const SizedBox(height: 22),
                    ],
                    if (steps.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Instructions',
                          icon: Icons.format_list_numbered_rounded),
                      const SizedBox(height: 10),
                      ...steps.asMap().entries.map((e) =>
                          _StepRow(number: e.key + 1, text: e.value, luma: luma)),
                    ],
                    ...extraSections,
                  ],
                ),
              ),
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

// ---- Small shared pieces ---------------------------------------------------

Widget _favoriteOverlay({required bool active, required VoidCallback onTap}) =>
    FavoriteHeart(active: active, onTap: onTap);

Widget _circleButton(IconData icon, VoidCallback onTap) => MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );

Future<void> _openPhoto(BuildContext context, RecipesController controller,
    String photoId, String category) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (_) => GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: RemoteRecipeImage(
                controller: controller, photoId: photoId, category: category),
          ),
        ),
      ),
    ),
  );
}

Future<bool?> _confirmDelete(BuildContext context, String title,
    {String action = 'Delete'}) {
  final luma = context.luma;
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: luma.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: luma.border),
      ),
      title: Text('$action recipe?',
          style: TextStyle(
              color: luma.textPrimary, fontWeight: FontWeight.w700)),
      content: Text('"$title" will be ${action == 'Remove' ? 'removed from the public catalogue' : 'permanently deleted'}.',
          style: TextStyle(color: luma.textSecondary)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: luma.textSecondary))),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: TextStyle(color: luma.danger))),
      ],
    ),
  );
}

String _relativeDate(int ms) {
  if (ms == 0) return '';
  final then = DateTime.fromMillisecondsSinceEpoch(ms);
  final diff = DateTime.now().difference(then);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${then.day}/${then.month}/${then.year}';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        Icon(icon, size: 16, color: luma.accent),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: luma.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.luma,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final LumaPalette luma;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: luma.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: luma.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: luma.textSecondary, fontSize: 13)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  const _SmallIconButton(
      {required this.icon, required this.onTap, required this.luma});
  final IconData icon;
  final VoidCallback? onTap;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: onTap != null
              ? luma.accentSubtle
              : luma.border.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 14, color: onTap != null ? luma.accent : luma.textMuted),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow(
      {required this.ingredient, required this.scale, required this.luma});
  final RecipeIngredient ingredient;
  final double scale;
  final LumaPalette luma;

  String _scaledAmount() {
    if (ingredient.amount.isEmpty) return '';
    final n = double.tryParse(ingredient.amount);
    if (n == null) return ingredient.amount;
    final scaled = n * scale;
    if (scaled == scaled.truncateToDouble()) return scaled.toStringAsFixed(0);
    return scaled.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final amt = _scaledAmount();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: luma.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(ingredient.name,
                style: TextStyle(color: luma.textPrimary, fontSize: 14)),
          ),
          if (amt.isNotEmpty || ingredient.unit.isNotEmpty)
            Text(
              '${amt.isNotEmpty ? amt : ''}${ingredient.unit.isNotEmpty ? ' ${ingredient.unit}' : ''}'
                  .trim(),
              style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(
      {required this.number, required this.text, required this.luma});
  final int number;
  final String text;
  final LumaPalette luma;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: luma.accentSubtle,
                borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text('$number',
                  style: TextStyle(
                      color: luma.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text,
                  style: TextStyle(color: luma.textPrimary, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
