import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import 'engine_test_page.dart';
import 'hero_tile.dart';
import 'pagoda_test_page.dart';

/// The plugin's **Tests** section: a board of hero tiles, one per experiment,
/// each opening its own screen.
///
/// A [Wrap] rather than a grid so the tiles keep their size and simply flow
/// onto the next row — a hero tile that stretches to fill a column loses the
/// framing the artwork was cropped for.
class TestsTab extends StatelessWidget {
  const TestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tests',
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scratch space for experiments that are not ready to be a section '
            'of their own.',
            style: TextStyle(color: luma.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              LumaHeroTile(
                title: 'Pagoda Test',
                subtitle: 'Open the test screen',
                imageAsset: 'assets/tests/pagoda-preview.png',
                fallbackIcon: Icons.temple_buddhist_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PagodaTestPage(),
                  ),
                ),
              ),
              LumaHeroTile(
                title: 'Engine Test',
                subtitle: 'Open the test screen',
                imageAsset: 'assets/tests/engine-preview.png',
                fallbackIcon: Icons.precision_manufacturing_rounded,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EngineTestPage(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
