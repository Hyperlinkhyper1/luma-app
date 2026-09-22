import 'dart:convert';

import 'package:flutter/services.dart';

/// One procedural airport model shown in the Assets section.
///
/// The list lives in `assets/asset_studio/catalog.json` so the Flutter
/// gallery and the studio page read the same entries; each model's code is
/// `assets/asset_studio/models/<functionName>.js`.
class StudioAsset {
  const StudioAsset({
    required this.id,
    required this.name,
    required this.functionName,
    required this.description,
    required this.collectionCode,
    required this.category,
    required this.keywords,
    required this.width,
    required this.depth,
    required this.price,
  });

  factory StudioAsset.fromJson(Map<String, Object?> json) => StudioAsset(
    id: json['id']! as String,
    name: json['name']! as String,
    functionName: json['functionName']! as String,
    description: json['description']! as String,
    collectionCode: json['collectionCode']! as String,
    category: json['category']! as String,
    keywords: json['keywords']! as String,
    width: (json['width']! as num).toDouble(),
    depth: (json['depth']! as num).toDouble(),
    price: (json['price']! as num).toInt(),
  );

  final String id;
  final String name;
  final String functionName;
  final String description;
  final String collectionCode;
  final String category;
  final String keywords;

  /// Catalogue footprint in metres.
  final double width;
  final double depth;

  /// Build cost in euros.
  final int price;

  String get footprint => '${_metres(width)} × ${_metres(depth)} m';

  /// Isometric render of the model on a transparent background, baked from
  /// the model's own code so the gallery does not need a live 3D view.
  String get thumbnail => '$_dir/thumbs/$id.png';

  /// File name for a downloaded copy of the studio opened on this model.
  String get htmlFileName => '$functionName.html';

  static String _metres(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

const _dir = 'assets/asset_studio';
const _three = 'assets/airline_tycoon/scene/vendor/three-0.160.1.min.js';

/// Reads the catalogue from the bundle.
Future<List<StudioAsset>> loadStudioCatalog(AssetBundle bundle) async {
  final raw = jsonDecode(await bundle.loadString('$_dir/catalog.json'));
  return [
    for (final entry in raw as List)
      StudioAsset.fromJson(Map<String, Object?>.from(entry as Map)),
  ];
}

/// Assembles the asset studio as one self-contained HTML file — stylesheet,
/// three.js, every model and the studio script inlined — opened on [assetId].
///
/// The same file is shown in the app (with [embed] on, which hides the
/// studio's own title bar and model picker because luma draws those) and
/// saved by "Download HTML", where it works offline in any browser.
///
/// [theme] is `light`, `dark`, or `auto` to follow the browser — the app
/// passes its own theme so the studio is not a white page in dark mode, and
/// a downloaded copy is left on `auto`.
Future<String> buildAssetStudioHtml(
  AssetBundle bundle, {
  required String assetId,
  bool embed = false,
  String theme = 'auto',
}) async {
  final catalogJson = await bundle.loadString('$_dir/catalog.json');
  final catalog = jsonDecode(catalogJson) as List;
  final results = await Future.wait([
    bundle.loadString('$_dir/studio.html'),
    bundle.loadString('$_dir/studio.css'),
    bundle.loadString('$_dir/studio.js'),
    bundle.loadString(_three, cache: false),
    for (final entry in catalog)
      bundle.loadString('$_dir/models/${(entry as Map)['functionName']}.js'),
  ]);
  final [template, css, studio, three, ...models] = results;

  final config = jsonEncode({
    'asset': assetId,
    'embed': embed,
    'theme': theme,
    'catalog': catalog,
  }).replaceAll('</', r'<\/');
  final scripts = StringBuffer()
    ..writeln('<script>${_script(three)}</script>');
  for (var i = 0; i < catalog.length; i++) {
    final id = (catalog[i] as Map)['id'];
    scripts.writeln(
      '<script type="text/plain" data-model="$id">\n'
      '${_script(models[i])}\n</script>',
    );
  }
  scripts
    ..writeln('<script>window.STUDIO = $config;</script>')
    ..writeln('<script>${_script(studio)}</script>');

  return template
      .replaceFirst('<!-- @style -->', '<style>\n$css</style>')
      .replaceFirst('<!-- @scripts -->', scripts.toString());
}

/// Keeps inlined code from closing its own `<script>` element early.
String _script(String source) =>
    source.replaceAll(RegExp('</script', caseSensitive: false), r'<\/script');
