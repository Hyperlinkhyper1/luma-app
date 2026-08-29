import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:luma/features/converter/schematic/schematic_model.dart';
import 'package:luma/features/converter/schematic/textures/block_model_resolver.dart';
import 'package:luma/features/converter/schematic/textures/texture_pack_source_io.dart';
import 'package:luma/features/converter/schematic/textures/texture_pack_types.dart';

/// A solid-colour 16×16 PNG, standing in for a real block texture.
Uint8List _png(int r, int g, int b, {int a = 255, int size = 16}) {
  final image = img.Image(width: size, height: size, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(r, g, b, a));
  return Uint8List.fromList(img.encodePng(image));
}

/// A PNG with one see-through pixel, like leaves or glass.
Uint8List _pngWithHole() {
  final image = img.Image(width: 16, height: 16, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(80, 180, 60, 255));
  image.setPixelRgba(3, 4, 0, 0, 0, 0);
  return Uint8List.fromList(img.encodePng(image));
}

/// Blockstate and model JSON copied in shape from the game's own files, so
/// the resolver is exercised against the structures it will really meet.
RawTextureData _vanillaish() => RawTextureData(
      textures: {
        'block/stone': _png(126, 126, 126),
        'block/grass_block_top': _png(255, 255, 255),
        'block/grass_block_side': _png(150, 120, 80),
        'block/dirt': _png(134, 96, 67),
        'block/oak_log': _png(156, 123, 78),
        'block/oak_log_top': _png(190, 160, 100),
        'block/oak_planks': _png(176, 139, 80),
        'block/oak_leaves': _pngWithHole(),
        'block/furnace_front': _png(90, 90, 90),
        'block/furnace_side': _png(110, 110, 110),
        'block/furnace_top': _png(130, 130, 130),
      },
      blockstates: {
        'stone': '{"variants":{"":{"model":"minecraft:block/stone"}}}',
        'grass_block': '{"variants":{"snowy=false":'
            '{"model":"minecraft:block/grass_block"},'
            '"snowy=true":{"model":"minecraft:block/grass_block_snow"}}}',
        // The real oak_log blockstate, rotations included.
        'oak_log': '{"variants":{'
            '"axis=x":{"model":"minecraft:block/oak_log_horizontal",'
            '"x":90,"y":90},'
            '"axis=y":{"model":"minecraft:block/oak_log"},'
            '"axis=z":{"model":"minecraft:block/oak_log_horizontal","x":90}}}',
        'oak_stairs': '{"variants":{'
            '"facing=east,half=bottom,shape=straight":'
            '{"model":"minecraft:block/oak_stairs"},'
            '"facing=north,half=bottom,shape=straight":'
            '{"model":"minecraft:block/oak_stairs","y":270}}}',
        'oak_leaves': '{"variants":{"":{"model":"minecraft:block/oak_leaves"}}}',
        'furnace': '{"variants":{'
            '"facing=north,lit=false":{"model":"minecraft:block/furnace"},'
            '"facing=east,lit=false":'
            '{"model":"minecraft:block/furnace","y":90}}}',
        // A multipart block, like a fence or a wall.
        'oak_fence': '{"multipart":[{"apply":'
            '{"model":"minecraft:block/oak_fence_post"}},'
            '{"when":{"north":"true"},"apply":'
            '{"model":"minecraft:block/oak_fence_side"}}]}',
      },
      models: {
        'block/cube_all': '{"textures":{"particle":"#all","down":"#all",'
            '"up":"#all","north":"#all","east":"#all","south":"#all",'
            '"west":"#all"}}',
        'block/cube_column':
            '{"textures":{"particle":"#side","down":"#end","up":"#end",'
            '"north":"#side","east":"#side","south":"#side","west":"#side"}}',
        'block/stone':
            '{"parent":"minecraft:block/cube_all","textures":'
            '{"all":"minecraft:block/stone"}}',
        'block/grass_block': '{"parent":"minecraft:block/block","textures":'
            '{"particle":"minecraft:block/dirt",'
            '"bottom":"minecraft:block/dirt",'
            '"top":"minecraft:block/grass_block_top",'
            '"side":"minecraft:block/grass_block_side"}}',
        'block/oak_log':
            '{"parent":"minecraft:block/cube_column","textures":'
            '{"end":"minecraft:block/oak_log_top",'
            '"side":"minecraft:block/oak_log"}}',
        'block/oak_log_horizontal':
            '{"parent":"minecraft:block/cube_column_horizontal","textures":'
            '{"end":"minecraft:block/oak_log_top",'
            '"side":"minecraft:block/oak_log"}}',
        // Vanilla's horizontal column is the same face-to-texture mapping as
        // the upright one — it is the blockstate's x/y rotation that moves the
        // end grain onto the right pair of faces, which is exactly what the
        // rotation handling has to get right.
        'block/cube_column_horizontal':
            '{"textures":{"particle":"#side","down":"#end","up":"#end",'
            '"north":"#side","east":"#side","south":"#side","west":"#side"}}',
        'block/oak_stairs': '{"parent":"minecraft:block/stairs","textures":'
            '{"bottom":"minecraft:block/oak_planks",'
            '"top":"minecraft:block/oak_planks",'
            '"side":"minecraft:block/oak_planks"}}',
        'block/stairs': '{"textures":{"particle":"#side"}}',
        'block/oak_leaves':
            '{"parent":"minecraft:block/leaves","textures":'
            '{"all":"minecraft:block/oak_leaves"}}',
        'block/leaves': '{"parent":"minecraft:block/cube_all"}',
        'block/furnace': '{"parent":"minecraft:block/orientable","textures":'
            '{"front":"minecraft:block/furnace_front",'
            '"side":"minecraft:block/furnace_side",'
            '"top":"minecraft:block/furnace_top"}}',
        'block/orientable':
            '{"textures":{"particle":"#front","down":"#bottom","up":"#top",'
            '"north":"#front","east":"#side","south":"#side","west":"#side"}}',
        'block/oak_fence_post':
            '{"parent":"minecraft:block/cube_all","textures":'
            '{"all":"minecraft:block/oak_planks"}}',
        'block/block': '{}',
      },
      label: 'Test pack',
    );

/// Face order used everywhere: +X, -X, +Y, -Y, +Z, -Z.
const int east = 0;
const int west = 1;
const int up = 2;
const int down = 3;
const int south = 4;
const int north = 5;

void main() {
  final data = _vanillaish();
  final resolver = BlockModelResolver(
    blockstates: data.blockstates,
    models: data.models,
  );

  group('block model resolution', () {
    test('a simple cube uses one texture on every face', () {
      final faces = resolver.facesFor(BlockState('minecraft:stone'));
      for (final texture in faces.textures) {
        expect(texture, 'block/stone');
      }
    });

    test('a grass block gets grass on top and dirt underneath', () {
      final faces = resolver.facesFor(
        BlockState('minecraft:grass_block', const {'snowy': 'false'}),
      );
      expect(faces.textures[up], 'block/grass_block_top');
      expect(faces.textures[down], 'block/dirt');
      expect(faces.textures[north], 'block/grass_block_side');
      expect(faces.textures[east], 'block/grass_block_side');
    });

    test('only the top of a grass block is biome-tinted', () {
      final faces = resolver.facesFor(
        BlockState('minecraft:grass_block', const {'snowy': 'false'}),
      );
      expect(faces.tints[up], isNot(0xFFFFFFFF));
      expect(faces.tints[north], 0xFFFFFFFF);
      expect(faces.tints[down], 0xFFFFFFFF);
    });

    test('leaves are tinted on every face', () {
      final faces = resolver.facesFor(BlockState('minecraft:oak_leaves'));
      for (final tint in faces.tints) {
        expect(tint, isNot(0xFFFFFFFF));
      }
    });

    test('an upright log shows end grain on top and bottom only', () {
      final faces = resolver.facesFor(
        BlockState('minecraft:oak_log', const {'axis': 'y'}),
      );
      expect(faces.textures[up], 'block/oak_log_top');
      expect(faces.textures[down], 'block/oak_log_top');
      expect(faces.textures[north], 'block/oak_log');
      expect(faces.textures[east], 'block/oak_log');
    });

    test('a log lying east-west puts its end grain on the east and west', () {
      // This is the case model rotation exists for: the blockstate applies
      // x:90 and y:90, and getting the unrotation backwards puts the end
      // grain on the wrong pair of faces.
      final faces = resolver.facesFor(
        BlockState('minecraft:oak_log', const {'axis': 'x'}),
      );
      expect(faces.textures[east], 'block/oak_log_top');
      expect(faces.textures[west], 'block/oak_log_top');
      expect(faces.textures[up], 'block/oak_log');
      expect(faces.textures[north], 'block/oak_log');
    });

    test('a log lying north-south puts its end grain on the north and south',
        () {
      final faces = resolver.facesFor(
        BlockState('minecraft:oak_log', const {'axis': 'z'}),
      );
      expect(faces.textures[north], 'block/oak_log_top');
      expect(faces.textures[south], 'block/oak_log_top');
      expect(faces.textures[up], 'block/oak_log');
      expect(faces.textures[east], 'block/oak_log');
    });

    test('a furnace faces the way its block state says', () {
      final north0 = resolver.facesFor(
        BlockState('minecraft:furnace', const {
          'facing': 'north',
          'lit': 'false',
        }),
      );
      expect(north0.textures[north], 'block/furnace_front');
      expect(north0.textures[east], 'block/furnace_side');
      expect(north0.textures[up], 'block/furnace_top');

      final east90 = resolver.facesFor(
        BlockState('minecraft:furnace', const {
          'facing': 'east',
          'lit': 'false',
        }),
      );
      expect(east90.textures[east], 'block/furnace_front');
      expect(east90.textures[north], 'block/furnace_side');
      expect(east90.textures[up], 'block/furnace_top');
    });

    test('picks the variant that matches the properties', () {
      final faces = resolver.facesFor(
        BlockState('minecraft:oak_stairs', const {
          'facing': 'east',
          'half': 'bottom',
          'shape': 'straight',
        }),
      );
      expect(faces.textures[up], 'block/oak_planks');
    });

    test('handles a multipart block by taking its always-applied part', () {
      final faces = resolver.facesFor(
        BlockState('minecraft:oak_fence', const {'north': 'false'}),
      );
      expect(faces.textures[up], 'block/oak_planks');
    });

    test('falls back to the same-named texture for an unknown block', () {
      final faces = resolver.facesFor(BlockState('minecraft:mystery_block'));
      for (final texture in faces.textures) {
        expect(texture, 'block/mystery_block');
      }
    });
  });

  group('atlas packing', () {
    final atlas = buildAtlas(data);

    test('packs every texture plus the reserved white tile', () {
      expect(atlas.tiles.length, data.textures.length + 1);
      expect(atlas.tiles.containsKey(kSolidTileName), isTrue);
      expect(atlas.tiles.containsKey('block/stone'), isTrue);
    });

    test('the bitmap is large enough for the tiles it claims to hold', () {
      final rows = (atlas.tiles.length + atlas.columns - 1) ~/ atlas.columns;
      expect(atlas.width, atlas.columns * atlas.tileStride);
      expect(atlas.height, greaterThanOrEqualTo(rows * atlas.tileStride));
      expect(atlas.pixels.length, atlas.width * atlas.height * 4);
    });

    test('every tile lands inside the bitmap', () {
      for (final index in atlas.tiles.values) {
        final x = (index % atlas.columns) * atlas.tileStride;
        final y = (index ~/ atlas.columns) * atlas.tileStride;
        expect(x + atlas.tileStride, lessThanOrEqualTo(atlas.width));
        expect(y + atlas.tileStride, lessThanOrEqualTo(atlas.height));
      }
    });

    test('a tile holds the colour of the texture it came from', () {
      final index = atlas.tiles['block/stone']!;
      final x = (index % atlas.columns) * atlas.tileStride + 1 + 8;
      final y = (index ~/ atlas.columns) * atlas.tileStride + 1 + 8;
      final offset = (y * atlas.width + x) * 4;
      expect(atlas.pixels[offset], 126);
      expect(atlas.pixels[offset + 1], 126);
      expect(atlas.pixels[offset + 2], 126);
      expect(atlas.pixels[offset + 3], 255);
    });

    test('the reserved tile is opaque white', () {
      final index = atlas.tiles[kSolidTileName]!;
      final x = (index % atlas.columns) * atlas.tileStride + 1 + 8;
      final y = (index ~/ atlas.columns) * atlas.tileStride + 1 + 8;
      final offset = (y * atlas.width + x) * 4;
      expect(atlas.pixels.sublist(offset, offset + 4), [255, 255, 255, 255]);
    });

    test('notices which textures have holes in them', () {
      expect(atlas.transparentTextures, contains('block/oak_leaves'));
      expect(atlas.transparentTextures, isNot(contains('block/stone')));
    });

    test('carries the model data along for the resolver', () {
      expect(atlas.blockstates, isNotEmpty);
      expect(atlas.models, isNotEmpty);
    });

    test('scales a high-resolution pack down to the atlas tile size', () {
      final hd = RawTextureData(
        textures: {'block/stone': _png(10, 20, 30, size: 64)},
        blockstates: const <String, String>{},
        models: const <String, String>{},
        label: 'HD',
      );
      final packed = buildAtlas(hd);
      expect(packed.tileSize, 16);
      final index = packed.tiles['block/stone']!;
      final x = (index % packed.columns) * packed.tileStride + 1 + 8;
      final y = (index ~/ packed.columns) * packed.tileStride + 1 + 8;
      final offset = (y * packed.width + x) * 4;
      expect(packed.pixels[offset], 10);
      expect(packed.pixels[offset + 1], 20);
      expect(packed.pixels[offset + 2], 30);
    });

    test('takes the first frame of an animated texture', () {
      // Animated textures are a vertical strip; the frames after the first
      // must not end up squashed into the tile.
      final strip = img.Image(width: 16, height: 64, numChannels: 4);
      img.fill(strip, color: img.ColorRgba8(9, 9, 9, 255));
      img.fillRect(strip, x1: 0, y1: 0, x2: 15, y2: 15,
          color: img.ColorRgba8(200, 30, 40, 255));
      final animated = RawTextureData(
        textures: {
          'block/fire': Uint8List.fromList(img.encodePng(strip)),
        },
        blockstates: const <String, String>{},
        models: const <String, String>{},
        label: 'Animated',
      );
      final packed = buildAtlas(animated);
      final index = packed.tiles['block/fire']!;
      final x = (index % packed.columns) * packed.tileStride + 1 + 8;
      final y = (index ~/ packed.columns) * packed.tileStride + 1 + 8;
      final offset = (y * packed.width + x) * 4;
      expect(packed.pixels[offset], 200);
      expect(packed.pixels[offset + 1], 30);
    });

    test('a pack with no block textures is rejected, not left all white', () {
      // The reserved white tile must not be enough on its own to make an
      // unusable pack look loadable — that would paint every block white.
      final empty = buildAtlas(
        const RawTextureData(
          textures: <String, Uint8List>{},
          blockstates: <String, String>{},
          models: <String, String>{},
          label: 'Empty',
        ),
      );
      expect(empty.width, 0);
      expect(empty.tiles, isEmpty);
    });
  });

  group('version ordering', () {
    test('prefers the newest release', () {
      final versions = ['1.9', '1.21.4', '1.16.5', '1.20'];
      versions.sort(compareVersionIds);
      expect(versions.first, '1.21.4');
      expect(versions.last, '1.9');
    });

    test('sorts snapshots and modded ids below releases', () {
      final versions = ['1.20.1-forge-47.2.0', '1.20.1', '23w31a'];
      versions.sort(compareVersionIds);
      expect(versions.first, '1.20.1');
    });
  });
}
