import 'package:flutter/material.dart';

import '../theme/luma_theme.dart';

/// The slim header above the content area: just the active section title.
/// Theme and accent are now controlled from the Settings screen.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: luma.background,
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
