import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'transit_vehicle.dart';

/// Which layers the user last had switched on.
///
/// Kept in the plugin's own small JSON file rather than app-wide
/// [SettingsController], since nothing outside this plugin cares about it.
/// Writes are best-effort — a failure here must never break the map.
class TransportPrefs {
  const TransportPrefs({
    this.showVessels = true,
    this.showTransit = false,
    this.transitModes = const {
      TransitMode.highSpeed,
      TransitMode.train,
      TransitMode.metro,
      TransitMode.tram,
      TransitMode.bus,
      TransitMode.ferry,
    },
  });

  final bool showVessels;
  final bool showTransit;
  final Set<TransitMode> transitModes;

  static const _fileName = 'luma_transport_tracker.json';

  TransportPrefs copyWith({
    bool? showVessels,
    bool? showTransit,
    Set<TransitMode>? transitModes,
  }) =>
      TransportPrefs(
        showVessels: showVessels ?? this.showVessels,
        showTransit: showTransit ?? this.showTransit,
        transitModes: transitModes ?? this.transitModes,
      );

  static Future<File> _file([Directory? directory]) async {
    final dir = directory ?? await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<TransportPrefs> load({Directory? directory}) async {
    try {
      final file = await _file(directory);
      if (!await file.exists()) return const TransportPrefs();
      return fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return const TransportPrefs();
    }
  }

  Future<void> save({Directory? directory}) async {
    try {
      final file = await _file(directory);
      await file.writeAsString(jsonEncode(toJson()), flush: true);
    } catch (_) {
      // Preferences are a convenience; losing them is not worth an error.
    }
  }

  /// Bumped when the stored shape changes, so older files can be migrated
  /// rather than silently misread.
  static const schemaVersion = 2;

  /// Modes are persisted by what is *switched off*, not what is on.
  ///
  /// Storing the enabled set meant any mode added in a later version was
  /// absent from every existing file and therefore came back switched off —
  /// which is exactly how high-speed services ended up invisible for anyone
  /// who had used the plugin before that mode existed. Recording the hidden
  /// ones instead makes anything new default to visible.
  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'showVessels': showVessels,
        'showTransit': showTransit,
        'hiddenModes': TransitMode.values
            .where((m) => !transitModes.contains(m))
            .map((m) => m.name)
            .toList(),
      };

  static TransportPrefs fromJson(Map<String, dynamic> json) {
    final showVessels = json['showVessels'] as bool? ?? true;
    final showTransit = json['showTransit'] as bool? ?? false;
    final schema = json['schema'] as int? ?? 1;

    if (schema < schemaVersion) {
      // A version 1 file listed the enabled modes, so a mode introduced
      // later is indistinguishable from one the user turned off. The mode
      // filter is reset to everything visible; the layer toggles, which do
      // survive the change unambiguously, are kept.
      return TransportPrefs(
        showVessels: showVessels,
        showTransit: showTransit,
        transitModes: TransitMode.values.toSet(),
      );
    }

    final hidden = <TransitMode>{};
    for (final name in (json['hiddenModes'] as List?) ?? const []) {
      for (final mode in TransitMode.values) {
        if (mode.name == name) hidden.add(mode);
      }
    }
    return TransportPrefs(
      showVessels: showVessels,
      showTransit: showTransit,
      transitModes:
          TransitMode.values.where((m) => !hidden.contains(m)).toSet(),
    );
  }
}
