import 'sketch_blend.dart';

/// A layer as stored in `document.json`: its properties, and which PNG in
/// the document folder holds its pixels (null for an empty layer).
class SketchLayerMeta {
  const SketchLayerMeta({
    required this.id,
    required this.name,
    this.file,
    this.opacity = 1,
    this.blend = SketchBlend.normal,
    this.visible = true,
    this.locked = false,
    this.alphaLocked = false,
    this.clipped = false,
  });

  final int id;
  final String name;
  final String? file;
  final double opacity;
  final SketchBlend blend;
  final bool visible;
  final bool locked;
  final bool alphaLocked;
  final bool clipped;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'file': file,
        'opacity': opacity,
        'blend': blend.name,
        'visible': visible,
        'locked': locked,
        'alphaLocked': alphaLocked,
        'clipped': clipped,
      };

  static SketchLayerMeta fromJson(Map<String, Object?> json) => SketchLayerMeta(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? 'Layer',
        file: json['file'] as String?,
        opacity: (json['opacity'] as num?)?.toDouble().clamp(0.0, 1.0) ?? 1,
        blend: SketchBlend.parse(json['blend'] as String?),
        visible: json['visible'] != false,
        locked: json['locked'] == true,
        alphaLocked: json['alphaLocked'] == true,
        clipped: json['clipped'] == true,
      );
}

/// Everything about a document except its pixels.
class SketchMeta {
  const SketchMeta({
    required this.id,
    required this.title,
    required this.width,
    required this.height,
    required this.created,
    required this.updated,
    required this.layers,
    this.background = 0xFFFFFFFF,
    this.showBackground = true,
    this.activeLayerId,
  });

  static const format = 1;

  /// The folder name; stable for the life of the document.
  final String id;
  final String title;
  final int width;
  final int height;
  final DateTime created;
  final DateTime updated;

  /// Bottom to top.
  final List<SketchLayerMeta> layers;
  final int background;
  final bool showBackground;
  final int? activeLayerId;

  SketchMeta copyWith({
    String? title,
    DateTime? updated,
    List<SketchLayerMeta>? layers,
    int? background,
    bool? showBackground,
    int? activeLayerId,
  }) =>
      SketchMeta(
        id: id,
        title: title ?? this.title,
        width: width,
        height: height,
        created: created,
        updated: updated ?? this.updated,
        layers: layers ?? this.layers,
        background: background ?? this.background,
        showBackground: showBackground ?? this.showBackground,
        activeLayerId: activeLayerId ?? this.activeLayerId,
      );

  Map<String, Object?> toJson() => {
        'format': format,
        'title': title,
        'width': width,
        'height': height,
        'created': created.toUtc().toIso8601String(),
        'updated': updated.toUtc().toIso8601String(),
        'background': background,
        'showBackground': showBackground,
        'activeLayer': activeLayerId,
        'layers': [for (final layer in layers) layer.toJson()],
      };

  static SketchMeta fromJson(String id, Map<String, Object?> json) {
    final width = (json['width'] as num?)?.toInt() ?? 0;
    final height = (json['height'] as num?)?.toInt() ?? 0;
    if (width <= 0 || height <= 0) {
      throw const FormatException('Document has no canvas size.');
    }
    final layers = [
      for (final raw in (json['layers'] as List? ?? const []))
        if (raw is Map) SketchLayerMeta.fromJson(raw.cast<String, Object?>()),
    ];
    return SketchMeta(
      id: id,
      title: json['title'] as String? ?? 'Untitled',
      width: width,
      height: height,
      created: DateTime.tryParse(json['created'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      updated: DateTime.tryParse(json['updated'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      background: (json['background'] as num?)?.toInt() ?? 0xFFFFFFFF,
      showBackground: json['showBackground'] != false,
      activeLayerId: (json['activeLayer'] as num?)?.toInt(),
      layers: layers,
    );
  }
}

/// Canvas size presets offered when creating a document.
class CanvasPreset {
  const CanvasPreset(this.name, this.width, this.height, {this.note});

  final String name;
  final int width;
  final int height;
  final String? note;

  static const all = [
    CanvasPreset('Screen', 1920, 1080, note: 'Full HD'),
    CanvasPreset('Square', 2048, 2048),
    CanvasPreset('Portrait', 1536, 2048, note: '3:4'),
    CanvasPreset('A4', 2480, 3508, note: '300 dpi'),
    CanvasPreset('A4 draft', 1240, 1754, note: '150 dpi'),
    CanvasPreset('4K', 3840, 2160, note: 'UHD'),
    CanvasPreset('Comic page', 1988, 3075, note: '6.6×10.2 in'),
    CanvasPreset('Phone wallpaper', 1284, 2778),
  ];

  /// The largest side we allow. Past this a single layer is over 64 MB of
  /// GPU memory and history gets too short to be useful.
  static const maxSide = 4096;
  static const minSide = 64;
}
