import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../theme/luma_theme.dart';
import 'ai_benchmark_repository.dart';
import 'ai_benchmark_scope.dart';
import 'engine_test_page.dart';
import 'hero_tile.dart';
import 'pagoda_test_page.dart';
import 'pc_test_page.dart';

/// The plugin's **Tests** section: a board of hero tiles, one per experiment,
/// each opening its own screen.
///
/// A [Wrap] rather than a grid so the tiles keep their size and simply flow
/// onto the next row — a hero tile that stretches to fill a column loses the
/// framing the artwork was cropped for.
///
/// Tile artwork downloads from the luma server with the benchmark roster (see
/// [AiBenchmarkScope]); until it arrives the tiles show their gradient
/// stand-in, so the tab looks deliberate with no account at all.
class TestsTab extends StatefulWidget {
  const TestsTab({super.key});

  @override
  State<TestsTab> createState() => _TestsTabState();
}

class _TestsTabState extends State<TestsTab> {
  bool _started = false;

  /// Drawn once per visit to the tab, so the three tiles show a different
  /// scene's artwork each time the section is opened rather than the same
  /// frozen picture forever. Held in state — re-rolling it on every build
  /// would reshuffle the board on hover.
  final int _seed = Random().nextInt(1 << 32);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiBenchmarkScope.of(context).load();
  }

  /// Artwork for a test's tile: one of that test's own scene previews, picked
  /// at random for this visit, falling back to the test's generic artwork
  /// while the previews are still downloading (and to the gradient stand-in
  /// when there is nothing cached at all).
  ///
  /// The pick is taken over the whole roster rather than only the previews
  /// already on disk, so a preview arriving mid-visit never swaps the picture
  /// out from under the user.
  File? _tileArt(AiBenchmarkRepository repo, String kind) {
    final fallback = repo.fallbackFile(kind);
    final roster = repo.benchmarksOfKind(kind);
    if (roster.isEmpty) return fallback;
    final index = (_seed ^ kind.hashCode).abs() % roster.length;
    return repo.previewFile(roster[index].id) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final repo = AiBenchmarkScope.of(context);
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) => SingleChildScrollView(
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
                  imageFile: _tileArt(repo, 'pagoda'),
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
                  imageFile: _tileArt(repo, 'engine'),
                  fallbackIcon: Icons.precision_manufacturing_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EngineTestPage(),
                    ),
                  ),
                ),
                LumaHeroTile(
                  title: 'PC Test',
                  subtitle: 'Open the test screen',
                  imageFile: _tileArt(repo, 'pc'),
                  fallbackIcon: Icons.computer_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PcTestPage(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
