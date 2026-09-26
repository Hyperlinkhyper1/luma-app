import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PresetLightSetting {
  const PresetLightSetting({
    required this.lightId,
    this.brightness,
    this.hue,
    this.saturation,
  });

  final String lightId;
  final int? brightness;
  final int? hue;
  final double? saturation;

  Map<String, Object> toJson() {
    final json = <String, Object>{'lightId': lightId};
    if (brightness != null) json['brightness'] = brightness!;
    if (hue != null) json['hue'] = hue!;
    if (saturation != null) json['saturation'] = saturation!;
    return json;
  }

  factory PresetLightSetting.fromJson(Map<String, dynamic> json) {
    final brightness = (json['brightness'] as num?)?.round();
    final hue = (json['hue'] as num?)?.round();
    final saturation = (json['saturation'] as num?)?.toDouble();
    if (brightness != null && (brightness < 1 || brightness > 100) ||
        hue != null && (hue < 0 || hue > 359) ||
        saturation != null && (saturation < 0 || saturation > 1) ||
        (hue == null) != (saturation == null)) {
      throw const FormatException('Invalid preset lamp settings.');
    }
    return PresetLightSetting(
      lightId: json['lightId'] as String,
      brightness: brightness,
      hue: hue,
      saturation: saturation,
    );
  }
}

class SmartHomePreset {
  const SmartHomePreset({
    required this.id,
    required this.name,
    required this.lights,
  });

  final String id;
  final String name;
  final List<PresetLightSetting> lights;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'lights': lights.map((light) => light.toJson()).toList(),
  };

  factory SmartHomePreset.fromJson(Map<String, dynamic> json) =>
      SmartHomePreset(
        id: json['id'] as String,
        name: json['name'] as String,
        lights: (json['lights'] as List)
            .map(
              (item) => PresetLightSetting.fromJson(
                (item as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
      );
}

abstract class SmartHomePresetStore {
  Future<List<SmartHomePreset>> load();
  Future<void> save(List<SmartHomePreset> presets);
}

class FileSmartHomePresetStore implements SmartHomePresetStore {
  const FileSmartHomePresetStore();

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}luma_smart_home_presets.json',
    );
  }

  @override
  Future<List<SmartHomePreset>> load() async {
    final file = await _file();
    if (!await file.exists()) return const [];
    final decoded = jsonDecode(await file.readAsString()) as List;
    return decoded
        .map(
          (item) =>
              SmartHomePreset.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  @override
  Future<void> save(List<SmartHomePreset> presets) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(presets.map((p) => p.toJson()).toList()),
    );
  }
}
