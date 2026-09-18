import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';

/// Search field for filtering the model list on a benchmark's selection
/// screen. Shared by [PagodaTestPage] and [EngineTestPage] so both screens
/// filter the same way.
class ModelSearchField extends StatelessWidget {
  const ModelSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search models',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: luma.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(color: luma.textMuted, fontSize: 13),
          prefixIcon:
              Icon(Icons.search_rounded, size: 18, color: luma.textMuted),
          filled: true,
          fillColor: luma.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: luma.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: luma.accent),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: luma.border),
          ),
        ),
      ),
    );
  }
}
