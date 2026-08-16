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

  Map<String, dynamic> toJson() => {
        'showVessels': showVessels,
        'showTransit': showTransit,
        'transitModes': transitModes.map((m) => m.name).toList(),
      };

  static TransportPrefs fromJson(Map<String, dynamic> json) {
    final modeNames = (json['transitModes'] as List?)?.cast<Object?>() ?? const [];
    final modes = <TransitMode>{};
    for (final name in modeNames) {
      for (final mode in TransitMode.values) {
        if (mode.name == name) modes.add(mode);
      }
    }
    return TransportPrefs(
      showVessels: json['showVessels'] as bool? ?? true,
      showTransit: json['showTransit'] as bool? ?? false,
      // An empty saved set is honoured; a missing key falls back to all.
      transitModes: modeNames.isEmpty ? TransitMode.values.toSet() : modes,
    );
  }
}
