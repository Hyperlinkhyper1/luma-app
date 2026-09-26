class SmartLight {
  const SmartLight({
    required this.id,
    required this.name,
    required this.isOn,
    required this.isReachable,
    required this.canReceive,
    this.room,
    this.lightLevel,
    this.colorTemperature,
    this.colorTemperatureMin,
    this.colorTemperatureMax,
    this.colorHue,
    this.colorSaturation,
  });

  final String id;
  final String name;
  final String? room;
  final bool isOn;
  final bool isReachable;
  final Set<String> canReceive;
  final int? lightLevel;
  final int? colorTemperature;
  final int? colorTemperatureMin;
  final int? colorTemperatureMax;
  final int? colorHue;
  final double? colorSaturation;

  bool get canToggle => canReceive.contains('isOn');
  bool get canDim => canReceive.contains('lightLevel');
  bool get canSetTemperature =>
      canReceive.contains('colorTemperature') &&
      colorTemperatureMin != null &&
      colorTemperatureMax != null &&
      colorTemperatureMin! > colorTemperatureMax!;
  bool get canSetColor =>
      canReceive.contains('colorHue') && canReceive.contains('colorSaturation');

  factory SmartLight.fromJson(Map<String, dynamic> json) {
    final attributes =
        (json['attributes'] as Map?)?.cast<String, dynamic>() ?? {};
    final capabilities =
        (json['capabilities'] as Map?)?.cast<String, dynamic>() ?? {};
    final room = (json['room'] as Map?)?.cast<String, dynamic>();
    final name = attributes['customName'] as String?;
    return SmartLight(
      id: json['id'] as String,
      name: name == null || name.trim().isEmpty
          ? (attributes['model'] as String? ?? 'IKEA lamp')
          : name,
      room: room?['name'] as String?,
      isOn: attributes['isOn'] == true,
      isReachable: json['isReachable'] != false,
      canReceive: (capabilities['canReceive'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      lightLevel: (attributes['lightLevel'] as num?)?.round(),
      colorTemperature: (attributes['colorTemperature'] as num?)?.round(),
      colorTemperatureMin: (attributes['colorTemperatureMin'] as num?)?.round(),
      colorTemperatureMax: (attributes['colorTemperatureMax'] as num?)?.round(),
      colorHue: (attributes['colorHue'] as num?)?.round(),
      colorSaturation: (attributes['colorSaturation'] as num?)?.toDouble(),
    );
  }
}
