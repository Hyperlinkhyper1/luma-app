import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/enchant_optimizer.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/leather_dye.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/map_art.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/mc_dyes.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/mc_registries_data.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/mc_text.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/ores_data.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/roofs.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/shapes.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/skin_model.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/data/sulfur_cube_data.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/mc_tool_catalog.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/tools/players/villager_guide_tool.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/ui/mc_files.dart';
import 'package:luma/features/plugins/installed/game_tools/minecraft/ui/mc_schematic_panel.dart';

McBook _book(String id, int level) => McBook(kMcEnchants[id]!, level);

void main() {
  group('catalogue', () {
    test('splits the 29 tools across the three sub-tabs', () {
      expect(McTool.values, hasLength(29));
      expect(McAudience.players.tools, hasLength(16));
      expect(McAudience.admins.tools, hasLength(9));
      expect(McAudience.developers.tools, hasLength(4));
      for (final group in McToolGroup.values) {
        expect(group.tools, isNotEmpty, reason: '${group.name} has no tools');
      }
    });
  });

  group('anvil optimizer', () {
    test('one book costs its level times the book multiplier', () {
      final plan = mcOptimizeAnvil([_book('sharpness', 5)])!;
      expect(plan.steps, hasLength(1));
      expect(plan.totalLevels, 5);
      expect(plan.finalPenalty, 1);
    });

    test('two books straight onto the item beat merging them first', () {
      final plan = mcOptimizeAnvil([_book('mending', 1), _book('unbreaking', 3)])!;
      // Mending (2) then Unbreaking (3 + 1 prior work) — 6. Merging the books
      // first would cost 2 + (5 + 1) = 8.
      expect(plan.totalLevels, 6);
      expect(plan.steps, hasLength(2));
    });

    test('a full sword never exceeds the survival limit and beats naive order', () {
      final books = [
        _book('sharpness', 5),
        _book('looting', 3),
        _book('unbreaking', 3),
        _book('mending', 1),
        _book('sweeping_edge', 3),
        _book('fire_aspect', 2),
        _book('knockback', 2),
      ];
      final plan = mcOptimizeAnvil(books)!;
      expect(plan.maxStep, lessThanOrEqualTo(39));
      expect(plan.steps, hasLength(books.length));
      expect(plan.root.books.map((b) => b.enchant.id).toSet(), books.map((b) => b.enchant.id).toSet());

      // Applying the books one by one is the naive order; the optimum is at
      // least as cheap.
      var naive = 0;
      var penalty = 0;
      for (final b in books) {
        naive += b.value + mcPenaltyCost(penalty);
        penalty++;
      }
      expect(plan.totalLevels, lessThanOrEqualTo(naive));
    });

    test('step costs add up to the total', () {
      final plan = mcOptimizeAnvil([
        _book('protection', 4),
        _book('unbreaking', 3),
        _book('mending', 1),
        _book('thorns', 3),
      ])!;
      expect(plan.steps.fold(0, (s, e) => s + e.cost), plan.totalLevels);
    });

    test('merging books into one book works without an item', () {
      final plan = mcOptimizeAnvil(
        [_book('protection', 4), _book('unbreaking', 3)],
        targetIsBook: true,
      )!;
      expect(plan.steps, hasLength(1));
      // The cheaper sacrifice: Protection IV is 4, Unbreaking III is 3.
      expect(plan.totalLevels, 3);
    });

    test('conflicts follow the exclusive sets', () {
      expect(kMcEnchants['sharpness']!.conflictsWith(kMcEnchants['smite']!), isTrue);
      expect(kMcEnchants['infinity']!.conflictsWith(kMcEnchants['mending']!), isTrue);
      expect(kMcEnchants['riptide']!.conflictsWith(kMcEnchants['loyalty']!), isTrue);
      expect(kMcEnchants['protection']!.conflictsWith(kMcEnchants['unbreaking']!), isFalse);
    });

    test('experience points follow the game formula', () {
      expect(mcXpForLevel(0), 0);
      expect(mcXpForLevel(16), 352);
      expect(mcXpForLevel(30), 1395);
      expect(mcXpForLevel(39), 2727);
    });
  });

  group('leather dye', () {
    test('one dye gives its own colour', () {
      expect(mcMixLeather([McDye.red]), McDye.red.rgb);
      expect(mcMixLeather([McDye.white]), McDye.white.rgb);
    });

    test('mixes average and rescale like the game', () {
      // (176+60)/2, (46+68)/2, (38+170)/2 = 118, 57, 104; brightest-average
      // is (176+170)/2 = 173, so everything scales by 173/118.
      expect(mcMixLeather([McDye.red, McDye.blue]), 0xAD5398);
    });

    test('finds an exact single-dye match', () {
      final match = mcBestDyeMix(McDye.lime.rgb, maxDyes: 3);
      expect(match.deltaE, closeTo(0, 0.001));
      expect(match.dyes, [McDye.lime]);
    });
  });

  group('shapes', () {
    test('a filled circle is symmetric and close to πr²', () {
      final cells = mcEllipse(21, 21, filled: true);
      expect(cells.length, closeTo(math.pi * 10.5 * 10.5, 25));
      for (final (x, y) in cells) {
        expect(cells.contains((20 - x, y)), isTrue);
        expect(cells.contains((x, 20 - y)), isTrue);
      }
    });

    test('a ring has no holes in a thick outline', () {
      final ring = mcEllipse(15, 15, thick: true);
      final filled = mcEllipse(15, 15, filled: true);
      expect(ring.difference(filled), isEmpty);
      expect(ring.length, lessThan(filled.length));
    });

    test('a hollow sphere is a shell', () {
      final shell = mcSolid(McSolid.sphere, width: 11, height: 11, depth: 11);
      final solid = mcSolid(McSolid.sphere, width: 11, height: 11, depth: 11, hollow: false);
      expect(shell.length, lessThan(solid.length));
      expect(shell.contains((5, 5, 5)), isFalse);
      expect(solid.contains((5, 5, 5)), isTrue);
    });

    test('an arch spans its width and reaches its rise', () {
      final arch = mcArch(9, 5, McArchStyle.round, thickness: 1);
      expect(arch.map((c) => c.$1).toSet(), {0, 1, 2, 3, 4, 5, 6, 7, 8});
      expect(arch.map((c) => c.$2).reduce(math.max), 4);
    });
  });

  group('roofs', () {
    test('a gable roof faces its stairs up both slopes', () {
      final roof = mcGenerateRoof(
        style: McRoofStyle.gable,
        width: 7,
        depth: 5,
        material: kMcRoofMaterials.first,
        overhang: 0,
      );
      final facings = roof.blocks.values
          .where((s) => s.name.endsWith('_stairs'))
          .map((s) => s.properties['facing'])
          .toSet();
      expect(facings, {'north', 'south'});
      expect(roof.peak, greaterThanOrEqualTo(2));
    });

    test('a hip roof turns its corners with outer stair shapes', () {
      final roof = mcGenerateRoof(
        style: McRoofStyle.hip,
        width: 9,
        depth: 9,
        material: kMcRoofMaterials.first,
        overhang: 0,
        ridgeCap: false,
      );
      final shapes = roof.blocks.values
          .where((s) => s.name.endsWith('_stairs'))
          .map((s) => s.properties['shape'])
          .toSet();
      expect(shapes, contains('straight'));
      expect(shapes.any((s) => s!.startsWith('outer_')), isTrue);
      final facings = roof.blocks.values
          .where((s) => s.name.endsWith('_stairs'))
          .map((s) => s.properties['facing'])
          .toSet();
      expect(facings, {'north', 'south', 'east', 'west'});
    });

    test('roof blocks become a schematic', () {
      final roof = mcGenerateRoof(
        style: McRoofStyle.gambrel,
        width: 11,
        depth: 9,
        material: kMcRoofMaterials[1],
        gableFill: 'spruce_planks',
      );
      final voxels = McVoxels();
      for (final e in roof.blocks.entries) {
        voxels.set(e.key.$1, e.key.$2, e.key.$3, e.value);
      }
      final s = voxels.build();
      expect(s.blockCount, roof.blocks.length);
      expect(s.width, 13);
    });
  });

  group('map art', () {
    McMapArtResult convert(int rgb, {bool staircase = false}) {
      final pixels = Uint8List(128 * 128 * 4);
      for (var i = 0; i < 128 * 128; i++) {
        pixels[i * 4] = (rgb >> 16) & 0xFF;
        pixels[i * 4 + 1] = (rgb >> 8) & 0xFF;
        pixels[i * 4 + 2] = rgb & 0xFF;
        pixels[i * 4 + 3] = 255;
      }
      return mcConvertMapArt(McMapArtJob(
        pixels: pixels,
        width: 128,
        height: 128,
        colors: [for (var i = 0; i < kMcMapColors.length; i++) i],
        staircase: staircase,
        dither: McDither.none,
      ));
    }

    test('an exact map colour maps to itself, flat', () {
      final grass = kMcMapColors.indexWhere((c) => c.id == 1);
      final r = convert(mcShade(kMcMapColors[grass].rgb, 220));
      expect(r.color.every((c) => c == grass), isTrue);
      expect(r.shade.every((s) => s == 1), isTrue);
    });

    test('staircase heights never go negative', () {
      final r = convert(mcShade(kMcMapColors[5].rgb, 255), staircase: true);
      final heights = mcStaircaseHeights(r);
      expect(heights.reduce(math.min), 0);
      // All brighter shades: each column climbs one block per row.
      expect(heights.reduce(math.max), 128);
    });
  });

  group('text codes', () {
    test('legacy codes parse into styled spans', () {
      final spans = mcParseLegacy('&cHello &lWorld&r!');
      expect(spans.map((s) => s.text).toList(), ['Hello ', 'World', '!']);
      expect(spans[0].color, 'red');
      expect(spans[1].bold, isTrue);
      expect(spans[1].color, 'red');
      expect(spans[2].color, isNull);
    });

    test('components use the 26.x event names', () {
      final json = mcComponentJson([
        McTextSpan(text: 'Go', color: 'aqua', click: McClickAction.runCommand, clickValue: '/spawn', hover: 'Teleport'),
      ]);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['click_event'], {'action': 'run_command', 'command': '/spawn'});
      expect(decoded['hover_event'], {'action': 'show_text', 'value': 'Teleport'});
    });

    test('plain text stays a bare string', () {
      expect(mcComponentJson([McTextSpan(text: 'hi')]), '"hi"');
    });

    test('server.properties escapes the section sign', () {
      expect(mcPropertiesEscape('§aHi'), r'\u00A7aHi');
      expect(mcToLegacy(mcParseLegacy('&6Gold')), '§6Gold');
    });
  });

  group('skins', () {
    test('the default skin round-trips through PNG', () {
      final skin = mcDefaultSkin();
      final back = McSkin.fromPng(skin.toPng())!;
      expect(back.pixels, skin.pixels);
    });

    test('every model face samples inside the 64 × 64 texture', () {
      for (final slim in [false, true]) {
        for (final box in mcSkinBoxes(slim: slim)) {
          for (final f in mcSkinFaces(box)) {
            expect(f.u + f.tw, lessThanOrEqualTo(64), reason: box.name);
            expect(f.v + f.th, lessThanOrEqualTo(64), reason: box.name);
          }
        }
      }
    });
  });

  group('generated game data', () {
    test('every traded item is a real item', () {
      expect(debugVillagerItemsKnown(), isTrue);
    });

    test('tables are populated', () {
      expect(kMcItems, contains('diamond_sword'));
      expect(kMcCubeArchetypes, hasLength(12));
      expect(kMcOres.map((o) => o.id), containsAll(['diamond', 'ancient_debris']));
      for (final enchant in kMcEnchants.keys) {
        expect(kMcEnchantments, contains(enchant));
      }
    });
  });

  group('datapacks', () {
    test('pack.mcmeta targets 26.1 through 26.3', () {
      final meta = jsonDecode(mcPackMeta('x')) as Map<String, dynamic>;
      expect((meta['pack'] as Map)['max_format'], 121);
    });

    test('slugs are id-safe', () {
      expect(mcSlug('My Cool World!'), 'my_cool_world');
      expect(mcSlug('   '), 'custom');
    });
  });
}
