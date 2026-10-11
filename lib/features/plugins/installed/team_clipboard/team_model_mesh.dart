import 'dart:math' as math;
import 'dart:typed_data';

/// A texture the board holds, as the 3D view needs it: its pixels, so a
/// flat item sprite can be given edges, and the size of one frame, since an
/// animated strip's UVs address its first frame only.
class TeamSprite {
  const TeamSprite({
    required this.key,
    required this.width,
    required this.height,
    this.rgba,
  });

  /// What the painter looks the image up by (the file id).
  final String key;
  final int width;

  /// The whole image's height; [frameHeight] is one frame of it.
  final int height;

  /// The pixels, row by row. Left out for a big image: without them an item
  /// is drawn as its front and back only, with no edges.
  final Uint8List? rgba;

  int get frameHeight =>
      width > 0 && height > width && height % width == 0 ? width : height;
}

/// One textured face, ready to project: four corners in model space
/// (0–16 on each axis, Minecraft's units) wound top-left, top-right,
/// bottom-right, bottom-left as seen from outside, with the matching UVs as
/// 0–1 fractions of one frame of [texture].
class TeamModelQuad {
  const TeamModelQuad(this.texture, this.points, this.uvs, this.shade);

  /// The [TeamSprite.key] to paint with, or null when the model names a
  /// texture the entry doesn't have.
  final String? texture;
  final Float64List points;
  final Float64List uvs;

  /// The game's fixed per-direction lighting: the top is full bright, the
  /// sides step down, the underside is darkest.
  final double shade;
}

class TeamModelMesh {
  const TeamModelMesh(this.quads, this.missing);

  final List<TeamModelQuad> quads;

  /// Texture names the model asked for that no attached .png matched.
  final List<String> missing;

  bool get isEmpty => quads.isEmpty;

  /// The centre and radius of a sphere around every corner, so the view
  /// can frame the model and keep its size steady while it turns.
  (double, double, double, double) get bounds {
    if (quads.isEmpty) return (8, 8, 8, 8);
    var minX = double.infinity, minY = double.infinity;
    var minZ = double.infinity, maxX = -double.infinity;
    var maxY = -double.infinity, maxZ = -double.infinity;
    for (final q in quads) {
      for (var i = 0; i < 12; i += 3) {
        minX = math.min(minX, q.points[i]);
        maxX = math.max(maxX, q.points[i]);
        minY = math.min(minY, q.points[i + 1]);
        maxY = math.max(maxY, q.points[i + 1]);
        minZ = math.min(minZ, q.points[i + 2]);
        maxZ = math.max(maxZ, q.points[i + 2]);
      }
    }
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final cz = (minZ + maxZ) / 2;
    var r = 0.0;
    for (final q in quads) {
      for (var i = 0; i < 12; i += 3) {
        final dx = q.points[i] - cx, dy = q.points[i + 1] - cy;
        final dz = q.points[i + 2] - cz;
        r = math.max(r, dx * dx + dy * dy + dz * dz);
      }
    }
    return (cx, cy, cz, math.max(math.sqrt(r), 0.5));
  }
}

/// Whether a parsed .json is a Minecraft model rather than a blockstate,
/// a loot table or anything else a team might attach.
bool teamLooksLikeModel(Map<String, dynamic> json) =>
    json['elements'] is List ||
    json['parent'] is String ||
    (json['textures'] is Map && json['variants'] == null);

/// The last path segment of a texture or model reference, lowercased:
/// `rubymod:item/ruby_sword` → `ruby_sword`. Files on the board are flat, so
/// this is what a reference is matched against.
String teamRefName(String ref) {
  var s = ref.trim().toLowerCase();
  final colon = s.indexOf(':');
  if (colon >= 0) s = s.substring(colon + 1);
  final slash = s.lastIndexOf('/');
  if (slash >= 0) s = s.substring(slash + 1);
  if (s.endsWith('.png')) s = s.substring(0, s.length - 4);
  if (s.endsWith('.json')) s = s.substring(0, s.length - 5);
  return s;
}

/// A flat item sprite, drawn the way the game draws `item/generated`: the
/// picture on the front and back, one pixel thick, with an edge wherever an
/// opaque pixel meets a clear one.
TeamModelMesh teamItemMesh(TeamSprite sprite) =>
    TeamModelMesh(_extrude(sprite), const []);

/// Turns a model and the board's textures into faces to draw.
///
/// [models] are the entry's other model files by [teamRefName], for a
/// `parent` the team uploaded too. A parent that isn't there but is one of
/// the game's own shapes (`item/generated`, the `block/cube` family,
/// `block/cross`, slabs) is rebuilt here from its well-known layout — no
/// vanilla file is read or shipped. A texture reference is matched to a
/// .png by name; when the entry has a single .png it stands in for any
/// name that doesn't match.
TeamModelMesh buildTeamModelMesh(
  Map<String, dynamic> model, {
  Map<String, Map<String, dynamic>> models = const {},
  required Map<String, TeamSprite> sprites,
}) {
  final textures = <String, String>{};
  List<dynamic>? elements;
  String? builtin;

  Map<String, dynamic>? current = model;
  final seen = <Map<String, dynamic>>{};
  for (var depth = 0; current != null && depth < 16; depth++) {
    if (!seen.add(current)) break;
    final own = current['textures'];
    if (own is Map) {
      own.forEach((k, v) {
        if (v is String) textures.putIfAbsent('$k', () => v);
      });
    }
    if (elements == null && current['elements'] is List) {
      elements = current['elements'] as List;
    }
    final parent = current['parent'];
    if (parent is! String) break;
    final name = teamRefName(parent);
    final uploaded = models[name];
    if (uploaded != null && !seen.contains(uploaded)) {
      current = uploaded;
    } else {
      if (elements == null) builtin = name;
      break;
    }
  }

  String? resolve(String ref) {
    var value = ref;
    for (var i = 0; i < 8 && value.startsWith('#'); i++) {
      final next = textures[value.substring(1)];
      if (next == null) return null;
      value = next;
    }
    return value.startsWith('#') ? null : value;
  }

  final missing = <String>{};
  String? spriteKey(String? ref) {
    if (ref == null) return null;
    final name = teamRefName(ref);
    final hit = sprites[name];
    if (hit != null) return hit.key;
    if (sprites.length == 1) return sprites.values.first.key;
    missing.add(name);
    return null;
  }

  final quads = <TeamModelQuad>[];

  if (elements == null && _generatedParents.contains(builtin)) {
    for (var layer = 0; layer < 5; layer++) {
      final ref = resolve('#layer$layer');
      if (ref == null) continue;
      final key = spriteKey(ref);
      final sprite = key == null
          ? null
          : sprites.values.where((s) => s.key == key).firstOrNull;
      if (sprite != null) quads.addAll(_extrude(sprite, layer: layer));
    }
    return TeamModelMesh(quads, missing.toList());
  }

  elements ??= _builtinElements(builtin, textures);
  for (final raw in elements) {
    if (raw is! Map) continue;
    final from = _vec(raw['from']);
    final to = _vec(raw['to']);
    if (from == null || to == null) continue;
    final faces = raw['faces'];
    if (faces is! Map) continue;
    final rotation = raw['rotation'];
    final shade = raw['shade'] != false;
    for (final dir in _Dir.values) {
      final face = faces[dir.name];
      if (face is! Map) continue;
      final points = _corners(dir, from, to);
      if (rotation is Map) _rotate(points, rotation);
      final uv = _faceUv(face['uv'], dir, from, to);
      final turn = ((face['rotation'] as num?)?.toInt() ?? 0) ~/ 90 % 4;
      final uvs = Float64List(8);
      for (var i = 0; i < 4; i++) {
        final c = (i - turn + 4) % 4;
        uvs[i * 2] = (c == 0 || c == 3 ? uv[0] : uv[2]) / 16;
        uvs[i * 2 + 1] = (c == 0 || c == 1 ? uv[1] : uv[3]) / 16;
      }
      final texture = face['texture'];
      quads.add(
        TeamModelQuad(
          spriteKey(texture is String ? resolve(texture) : null),
          points,
          uvs,
          shade ? dir.shade : 1,
        ),
      );
    }
  }
  return TeamModelMesh(quads, missing.toList());
}

const _generatedParents = {
  'generated',
  'handheld',
  'handheld_rod',
  'handheld_mace',
  'template_spawn_egg',
};

enum _Dir {
  north(0.8),
  south(0.8),
  west(0.6),
  east(0.6),
  up(1),
  down(0.5);

  const _Dir(this.shade);
  final double shade;
}

List<double>? _vec(Object? raw) {
  if (raw is! List || raw.length != 3) return null;
  final out = <double>[];
  for (final v in raw) {
    if (v is! num) return null;
    out.add(v.toDouble());
  }
  return out;
}

/// A face's four corners, wound top-left → top-right → bottom-right →
/// bottom-left as the texture sits on it seen from outside, which is the
/// order the game's default UVs run in.
Float64List _corners(_Dir dir, List<double> a, List<double> b) {
  final (x1, y1, z1) = (a[0], a[1], a[2]);
  final (x2, y2, z2) = (b[0], b[1], b[2]);
  return Float64List.fromList(switch (dir) {
    _Dir.north => [x2, y2, z1, x1, y2, z1, x1, y1, z1, x2, y1, z1],
    _Dir.south => [x1, y2, z2, x2, y2, z2, x2, y1, z2, x1, y1, z2],
    _Dir.west => [x1, y2, z1, x1, y2, z2, x1, y1, z2, x1, y1, z1],
    _Dir.east => [x2, y2, z2, x2, y2, z1, x2, y1, z1, x2, y1, z2],
    _Dir.up => [x1, y2, z1, x2, y2, z1, x2, y2, z2, x1, y2, z2],
    _Dir.down => [x1, y1, z2, x2, y1, z2, x2, y1, z1, x1, y1, z1],
  });
}

/// The face's `uv`, or the one the game derives from the element's
/// position when the model leaves it out.
List<double> _faceUv(Object? raw, _Dir dir, List<double> a, List<double> b) {
  if (raw is List && raw.length == 4 && raw.every((v) => v is num)) {
    return [for (final v in raw) (v as num).toDouble()];
  }
  final (x1, y1, z1) = (a[0], a[1], a[2]);
  final (x2, y2, z2) = (b[0], b[1], b[2]);
  return switch (dir) {
    _Dir.down => [x1, 16 - z2, x2, 16 - z1],
    _Dir.up => [x1, z1, x2, z2],
    _Dir.north => [16 - x2, 16 - y2, 16 - x1, 16 - y1],
    _Dir.south => [x1, 16 - y2, x2, 16 - y1],
    _Dir.west => [z1, 16 - y2, z2, 16 - y1],
    _Dir.east => [16 - z2, 16 - y2, 16 - z1, 16 - y1],
  };
}

/// An element's `rotation`: a turn about one axis through `origin`, with
/// `rescale` stretching the turned faces back out to the block's edges.
void _rotate(Float64List points, Map<dynamic, dynamic> rotation) {
  final angle = (rotation['angle'] as num?)?.toDouble() ?? 0;
  if (angle == 0) return;
  final origin = _vec(rotation['origin']) ?? const [8.0, 8.0, 8.0];
  final axis = rotation['axis'];
  final rad = angle * math.pi / 180;
  final c = math.cos(rad), s = math.sin(rad);
  final scale = rotation['rescale'] == true ? 1 / c.abs() : 1.0;
  for (var i = 0; i < 12; i += 3) {
    final x = points[i] - origin[0];
    final y = points[i + 1] - origin[1];
    final z = points[i + 2] - origin[2];
    final (nx, ny, nz) = switch (axis) {
      'x' => (x, (y * c - z * s) * scale, (y * s + z * c) * scale),
      'z' => ((x * c - y * s) * scale, (x * s + y * c) * scale, z),
      _ => ((x * c + z * s) * scale, y, (-x * s + z * c) * scale),
    };
    points[i] = nx + origin[0];
    points[i + 1] = ny + origin[1];
    points[i + 2] = nz + origin[2];
  }
}

/// The game's own shapes for a parent the team didn't upload, rebuilt from
/// their well-known layout. Anything unrecognised is drawn as a full cube,
/// each face taking whichever texture key fits it best.
List<dynamic> _builtinElements(String? parent, Map<String, String> textures) {
  String? pick(List<String> keys) {
    for (final k in keys) {
      if (textures.containsKey(k)) return '#$k';
    }
    for (final k in textures.keys) {
      if (k != 'particle') return '#$k';
    }
    return textures.containsKey('particle') ? '#particle' : null;
  }

  Map<String, dynamic> faces(Map<String, List<String>> keys) => {
    for (final e in keys.entries)
      if (pick(e.value) case final ref?) e.key: {'texture': ref},
  };

  final side = ['side', 'all', 'texture'];
  final cube = faces({
    'up': ['up', 'top', 'end', 'all', 'texture', 'side'],
    'down': ['down', 'bottom', 'end', 'top', 'all', 'texture', 'side'],
    'north': ['north', 'front', ...side],
    'south': ['south', ...side, 'front'],
    'west': ['west', ...side, 'front'],
    'east': ['east', ...side, 'front'],
  });

  switch (parent) {
    case 'cross' || 'tinted_cross':
      final ref = pick(['cross', 'texture', 'all']);
      Map<String, dynamic> plane(List<double> from, List<double> to, bool x) =>
          {
            'from': from,
            'to': to,
            'rotation': {
              'origin': [8, 8, 8],
              'axis': 'y',
              'angle': 45,
              'rescale': true,
            },
            'shade': false,
            'faces': {
              for (final d in x ? ['north', 'south'] : ['west', 'east'])
                d: {'texture': ref},
            },
          };
      return [
        plane([0.8, 0, 8], [15.2, 16, 8], true),
        plane([8, 0, 0.8], [8, 16, 15.2], false),
      ];
    case 'slab' || 'slab_top':
      final top = parent == 'slab_top';
      return [
        {
          'from': [0, top ? 8 : 0, 0],
          'to': [16, top ? 16 : 8, 16],
          'faces': cube,
        },
      ];
    default:
      return [
        {
          'from': [0, 0, 0],
          'to': [16, 16, 16],
          'faces': cube,
        },
      ];
  }
}

/// `item/generated`: the sprite on the front and (mirrored) on the back of
/// a one-pixel-thick slab, plus a one-pixel side wall wherever an opaque
/// pixel borders a clear one or the sprite's edge. Each side wall samples
/// the centre of its pixel, so it takes that pixel's colour exactly.
List<TeamModelQuad> _extrude(TeamSprite sprite, {int layer = 0}) {
  final w = sprite.width;
  final h = sprite.frameHeight;
  if (w <= 0 || h <= 0) return const [];
  final sx = 16 / w, sy = 16 / h;
  const front = 8.5, back = 7.5;
  final key = sprite.key;
  final slab = ([0.0, 0.0, back], [16.0, 16.0, front]);
  final quads = <TeamModelQuad>[
    TeamModelQuad(
      key,
      _corners(_Dir.south, slab.$1, slab.$2),
      Float64List.fromList([0, 0, 1, 0, 1, 1, 0, 1]),
      1,
    ),
    TeamModelQuad(
      key,
      _corners(_Dir.north, slab.$1, slab.$2),
      Float64List.fromList([1, 0, 0, 0, 0, 1, 1, 1]),
      1,
    ),
  ];
  final rgba = sprite.rgba;
  if (rgba == null) return _nudge(quads, layer);
  bool clear(int x, int y) =>
      x < 0 ||
      y < 0 ||
      x >= w ||
      y >= h ||
      rgba[(y * sprite.width + x) * 4 + 3] == 0;

  for (var py = 0; py < h; py++) {
    for (var px = 0; px < w; px++) {
      if (clear(px, py)) continue;
      final u = (px + 0.5) / w, v = (py + 0.5) / h;
      final uvs = Float64List.fromList([u, v, u, v, u, v, u, v]);
      final x1 = px * sx, x2 = (px + 1) * sx;
      final y2 = 16 - py * sy, y1 = 16 - (py + 1) * sy;
      final from = [x1, y1, back], to = [x2, y2, front];
      void wall(_Dir dir) => quads.add(
        TeamModelQuad(key, _corners(dir, from, to), uvs, dir.shade),
      );
      if (clear(px - 1, py)) wall(_Dir.west);
      if (clear(px + 1, py)) wall(_Dir.east);
      if (clear(px, py - 1)) wall(_Dir.up);
      if (clear(px, py + 1)) wall(_Dir.down);
    }
  }
  return _nudge(quads, layer);
}

/// Overlay layers sit a hair in front of the one below, so they win the
/// depth sort rather than flickering against it.
List<TeamModelQuad> _nudge(List<TeamModelQuad> quads, int layer) {
  if (layer == 0) return quads;
  final nudge = layer * 0.002;
  for (final q in quads) {
    for (var i = 2; i < 12; i += 3) {
      q.points[i] += q.points[i] > 8 ? nudge : -nudge;
    }
  }
  return quads;
}
