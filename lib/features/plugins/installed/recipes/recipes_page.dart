import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'recipes_detail.dart';
import 'recipes_editor.dart';
import 'recipes_models.dart';
import 'recipes_repository.dart';
import 'recipes_scope.dart';
import 'recipes_widgets.dart';

const _kFilterCategories = ['All', ...kRecipeCategories];

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  int _tab = 0; // 0 = Favourites, 1 = Public, 2 = Private
  String _search = '';
  String _category = 'All';

  bool _matches(String title, String? description, String category, List<String> extra) {
    if (_category != 'All' && category != _category) return false;
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (title.toLowerCase().contains(q)) return true;
    if ((description ?? '').toLowerCase().contains(q)) return true;
    return extra.any((e) => e.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final controller = RecipesScope.of(context);
    final luma = context.luma;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(controller),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final cat in _kFilterCategories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _CategoryChip(
                          label: cat,
                          selected: _category == cat,
                          color: cat == 'All'
                              ? luma.accent
                              : recipeCategoryColor(cat, luma),
                          onTap: () => setState(() => _category = cat),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => _tabBody(controller, luma),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: _Fab(
            onTap: () => showRecipeEditor(context, controller),
          ),
        ),
      ],
    );
  }

  Widget _header(RecipesController controller) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final tabs = [
          'Favourites${controller.favouriteCount > 0 ? ' (${controller.favouriteCount})' : ''}',
          'Public',
          'Private',
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _SearchBar(onChanged: (v) => setState(() => _search = v))),
                if (_tab == 1) ...[
                  const SizedBox(width: 12),
                  _RefreshButton(
                    loading: controller.loadingPublic,
                    onTap: () => controller.refreshPublic(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            LumaSegmentedTabs(
              tabs: tabs,
              selectedIndex: _tab,
              onSelect: (i) => setState(() => _tab = i),
            ),
          ],
        );
      },
    );
  }

  Widget _tabBody(RecipesController controller, LumaPalette luma) => switch (_tab) {
        0 => _favouritesTab(controller),
        1 => _publicTab(controller, luma),
        _ => _privateTab(controller),
      };

  // ---- Private -------------------------------------------------------------

  Widget _privateTab(RecipesController controller) {
    final recipes = controller.privateRecipes
        .where((r) => _matches(r.title, r.description, r.category,
            r.ingredients.map((i) => i.name).toList()))
        .toList();
    if (recipes.isEmpty) {
      return LumaEmptyState(
        icon: Icons.restaurant_menu_rounded,
        title: controller.privateRecipes.isEmpty
            ? 'No recipes yet'
            : 'No recipes found',
        subtitle: controller.privateRecipes.isEmpty
            ? 'Tap the + button to add your first recipe.'
            : 'Try a different search or category.',
      );
    }
    return _grid(recipes.length, (i) => _privateCard(controller, recipes[i]));
  }

  // ---- Public --------------------------------------------------------------

  Widget _publicTab(RecipesController controller, LumaPalette luma) {
    if (!controller.signedIn) {
      return const LumaEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Sign in to browse public recipes',
        subtitle:
            'Public recipes are shared through your sync account. Sign in under '
            'Settings → Sync & account to browse, publish, rate and review.',
      );
    }
    if (controller.loadingPublic && controller.publicRecipes.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(luma.accent)),
      );
    }
    if (controller.publicError != null && controller.publicRecipes.isEmpty) {
      return LumaEmptyState(
        icon: Icons.wifi_off_rounded,
        title: "Couldn't load public recipes",
        subtitle: controller.publicError,
      );
    }
    final recipes = controller.publicRecipes
        .where((r) => _matches(r.title, r.description, r.category,
            [r.authorName, ...r.ingredients.map((i) => i.name)]))
        .toList();
    if (recipes.isEmpty) {
      return LumaEmptyState(
        icon: Icons.public_rounded,
        title: controller.publicRecipes.isEmpty
            ? 'No public recipes yet'
            : 'No recipes found',
        subtitle: controller.publicRecipes.isEmpty
            ? 'Publish one of your recipes to get the catalogue started.'
            : 'Try a different search or category.',
      );
    }
    return _grid(recipes.length, (i) => _publicCard(controller, recipes[i]));
  }

  // ---- Favourites ----------------------------------------------------------

  Widget _favouritesTab(RecipesController controller) {
    final favs = controller.favouriteRecipes.where((r) {
      if (r is LocalRecipe) {
        return _matches(r.title, r.description, r.category,
            r.ingredients.map((i) => i.name).toList());
      }
      if (r is PublicRecipe) {
        return _matches(r.title, r.description, r.category,
            [r.authorName, ...r.ingredients.map((i) => i.name)]);
      }
      return false;
    }).toList();
    if (favs.isEmpty) {
      return const LumaEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No favourites yet',
        subtitle: 'Tap the heart on any recipe — private or public — to keep it here.',
      );
    }
    return _grid(favs.length, (i) {
      final r = favs[i];
      return r is LocalRecipe
          ? _privateCard(controller, r)
          : _publicCard(controller, r as PublicRecipe);
    });
  }

  // ---- Grid + cards --------------------------------------------------------

  Widget _grid(int count, Widget Function(int) builder) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = (constraints.maxWidth / 260).floor().clamp(1, 5);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.78,
          ),
          itemCount: count,
          itemBuilder: (context, i) => builder(i),
        );
      },
    );
  }

  Widget _privateCard(RecipesController controller, LocalRecipe recipe) {
    final timeStr = formatRecipeTime(recipe.totalMinutes);
    return _RecipeCardFrame(
      image: LocalRecipeImage(path: recipe.photoPath, category: recipe.category),
      category: recipe.category,
      favorite: recipe.isFavorite,
      onFavorite: () => controller.toggleFavoriteLocal(recipe.id),
      badge: recipe.isPublished ? _publishedBadge() : null,
      title: recipe.title,
      onTap: () => showLocalRecipeDetail(context, controller, recipe),
      meta: _MetaRow(items: [
        (Icons.people_outline_rounded, '${recipe.servings}'),
        if (timeStr.isNotEmpty) (Icons.schedule_rounded, timeStr),
        if (recipe.ingredients.isNotEmpty)
          (Icons.format_list_bulleted_rounded, '${recipe.ingredients.length}'),
      ]),
    );
  }

  Widget _publicCard(RecipesController controller, PublicRecipe recipe) {
    return _RecipeCardFrame(
      image: RemoteRecipeImage(
        controller: controller,
        photoId: recipe.photoId,
        category: recipe.category,
      ),
      category: recipe.category,
      favorite: controller.isFavoritePublic(recipe.id),
      onFavorite: () => controller.toggleFavoritePublic(recipe.id),
      title: recipe.title,
      onTap: () => showPublicRecipeDetail(context, controller, recipe),
      meta: _PublicMeta(recipe: recipe),
    );
  }

  Widget _publishedBadge() {
    return Builder(builder: (context) {
      final luma = context.luma;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public_rounded, size: 11, color: Colors.white),
            const SizedBox(width: 4),
            Text('Public',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    });
  }
}

// ---- Card frame ------------------------------------------------------------

class _RecipeCardFrame extends StatefulWidget {
  const _RecipeCardFrame({
    required this.image,
    required this.category,
    required this.favorite,
    required this.onFavorite,
    required this.title,
    required this.meta,
    required this.onTap,
    this.badge,
  });

  final Widget image;
  final String category;
  final bool favorite;
  final VoidCallback onFavorite;
  final String title;
  final Widget meta;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  State<_RecipeCardFrame> createState() => _RecipeCardFrameState();
}

class _RecipeCardFrameState extends State<_RecipeCardFrame> {
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
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hovering ? luma.accent : luma.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.image,
                    Positioned(
                      left: 10,
                      top: 10,
                      child: RecipeCategoryTag(category: widget.category),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: FavoriteHeart(
                          active: widget.favorite,
                          onTap: widget.onFavorite,
                          size: 18),
                    ),
                    if (widget.badge != null)
                      Positioned(left: 10, bottom: 10, child: widget.badge!),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    widget.meta,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.items});
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Icon(items[i].$1, size: 13, color: luma.textSecondary),
          const SizedBox(width: 4),
          Text(items[i].$2,
              style: TextStyle(color: luma.textSecondary, fontSize: 12)),
        ],
      ],
    );
  }
}

class _PublicMeta extends StatelessWidget {
  const _PublicMeta({required this.recipe});
  final PublicRecipe recipe;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      children: [
        RecipeStars(rating: recipe.ratingAvg, size: 13),
        const SizedBox(width: 5),
        Text(
          recipe.ratingCount == 0 ? 'New' : recipe.ratingAvg.toStringAsFixed(1),
          style: TextStyle(
              color: luma.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Icon(Icons.person_rounded, size: 12, color: luma.textMuted),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            recipe.mine ? 'You' : recipe.authorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: luma.textMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ---- Header pieces ---------------------------------------------------------

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: luma.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: luma.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 18, color: luma.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onChanged,
              style: TextStyle(color: luma.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search recipes…',
                hintStyle: TextStyle(color: luma.textMuted, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _ctrl.clear();
                widget.onChanged('');
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child:
                    Icon(Icons.close_rounded, size: 16, color: luma.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: luma.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: luma.border),
          ),
          child: loading
              ? Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(luma.accent)),
                  ),
                )
              : Icon(Icons.refresh_rounded, size: 20, color: luma.textSecondary),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.color.withValues(alpha: 0.18)
                : (_hovering ? luma.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: widget.selected ? widget.color : luma.border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.selected ? widget.color : luma.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Fab extends StatefulWidget {
  const _Fab({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_Fab> createState() => _FabState();
}

class _FabState extends State<_Fab> {
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
          duration: const Duration(milliseconds: 150),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _hovering ? luma.accentHover : luma.accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: luma.accent.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.add_rounded, color: luma.onAccent, size: 28),
        ),
      ),
    );
  }
}
