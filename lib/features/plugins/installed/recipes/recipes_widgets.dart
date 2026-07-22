import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/luma_theme.dart';
import 'recipes_models.dart';
import 'recipes_repository.dart';

const kStarColor = Color(0xFFF5B942);

IconData recipeCategoryIcon(String category) => switch (category) {
      'Breakfast' => Icons.egg_alt_rounded,
      'Lunch' => Icons.lunch_dining_rounded,
      'Dinner' => Icons.dinner_dining_rounded,
      'Dessert' => Icons.icecream_rounded,
      'Snack' => Icons.cookie_rounded,
      'Drink' => Icons.local_bar_rounded,
      'Baking' => Icons.bakery_dining_rounded,
      _ => Icons.restaurant_rounded,
    };

/// A read-only row of five stars with fractional (half-star) fill.
class RecipeStars extends StatelessWidget {
  const RecipeStars({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            rating >= i + 1
                ? Icons.star_rounded
                : (rating >= i + 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded),
            size: size,
            color: kStarColor,
          ),
      ],
    );
  }
}

/// Tappable five-star input. A value of 0 means "not yet rated".
class InteractiveStars extends StatelessWidget {
  const InteractiveStars({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 34,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: size,
                  color: i <= value ? kStarColor : luma.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A soft gradient placeholder shown when a recipe has no photo — tinted by
/// the recipe's category so cards still read at a glance.
class RecipePlaceholder extends StatelessWidget {
  const RecipePlaceholder({super.key, required this.category, this.iconSize = 40});

  final String category;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = recipeCategoryColor(category, luma);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Center(
        child: Icon(recipeCategoryIcon(category),
            size: iconSize, color: color.withValues(alpha: 0.85)),
      ),
    );
  }
}

/// A local (on-disk) recipe photo, falling back to a category placeholder.
class LocalRecipeImage extends StatelessWidget {
  const LocalRecipeImage({
    super.key,
    required this.path,
    required this.category,
    this.iconSize = 40,
  });

  final String? path;
  final String category;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null) {
      return RecipePlaceholder(category: category, iconSize: iconSize);
    }
    return Image.file(
      File(p),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) =>
          RecipePlaceholder(category: category, iconSize: iconSize),
    );
  }
}

/// A public recipe/review photo fetched from the server by id and cached in
/// the controller. Stateful so the fetch runs once, not on every rebuild.
class RemoteRecipeImage extends StatefulWidget {
  const RemoteRecipeImage({
    super.key,
    required this.controller,
    required this.photoId,
    required this.category,
    this.iconSize = 40,
  });

  final RecipesController controller;
  final String? photoId;
  final String category;
  final double iconSize;

  @override
  State<RemoteRecipeImage> createState() => _RemoteRecipeImageState();
}

class _RemoteRecipeImageState extends State<RemoteRecipeImage> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(RemoteRecipeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) {
      _bytes = null;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final id = widget.photoId;
    if (id == null || id.isEmpty) return;
    setState(() => _loading = true);
    final bytes = await widget.controller.publicPhoto(id);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            RecipePlaceholder(category: widget.category, iconSize: widget.iconSize),
      );
    }
    if (_loading && (widget.photoId?.isNotEmpty ?? false)) {
      return ColoredBox(
        color: luma.surfaceHover,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, valueColor: AlwaysStoppedAnimation(luma.accent)),
          ),
        ),
      );
    }
    return RecipePlaceholder(
        category: widget.category, iconSize: widget.iconSize);
  }
}

/// A small heart toggle used on cards and detail views.
class FavoriteHeart extends StatelessWidget {
  const FavoriteHeart({
    super.key,
    required this.active,
    required this.onTap,
    this.size = 20,
    this.background = true,
  });

  final bool active;
  final VoidCallback onTap;
  final double size;
  final bool background;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: background
              ? BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                )
              : null,
          child: Icon(
            active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: size,
            color: active
                ? const Color(0xFFE5647D)
                : (background ? Colors.white : luma.textMuted),
          ),
        ),
      ),
    );
  }
}

/// A shared, luma-styled text field for the recipe editor and review composer.
class RecipeTextField extends StatelessWidget {
  const RecipeTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.inputType,
    this.inputFormatters,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? inputType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: inputType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(color: luma.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: luma.textMuted, fontSize: 14),
        filled: true,
        fillColor: luma.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: BorderSide(color: luma.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: luma.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: luma.danger, width: 1.5),
        ),
      ),
    );
  }
}

class RecipeFieldLabel extends StatelessWidget {
  const RecipeFieldLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Text(
      label,
      style: TextStyle(
        color: luma.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Category pill used in the recipe editor's dropdown and detail header.
class RecipeCategoryTag extends StatelessWidget {
  const RecipeCategoryTag({super.key, required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final color = recipeCategoryColor(category, luma);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
