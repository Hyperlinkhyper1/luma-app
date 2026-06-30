import 'package:flutter/material.dart';

import '../../theme/luma_theme.dart';

/// The Plugins destination. Placeholder until plugin support ships.
class PluginsPage extends StatelessWidget {
  const PluginsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.extension_rounded, size: 48, color: luma.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Coming soon',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: luma.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Plugin support is on the way.',
            style: TextStyle(fontSize: 14, color: luma.textSecondary),
          ),
        ],
      ),
    );
  }
}
