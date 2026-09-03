import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'collage_maker_view.dart' show CollageSlot, CollageTemplate;

/// Icon shown for every user-created template — custom shapes have no
/// persisted [IconData], so they all share this one.
const IconData kCustomCollageIcon = Icons.crop_rounded;

Future<File> _customTemplatesFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}/luma_custom_collage_templates.json');
}

/// Loads user-created collage layouts from disk. Returns an empty list on
/// first run or if the file is missing/corrupt.
Future<List<CollageTemplate>> loadCustomCollageTemplates() async {
  try {
    final file = await _customTemplatesFile();
    if (!await file.exists()) return [];
    final raw = await file.readAsString();
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) {
      final map = e as Map<String, dynamic>;
      final slots = (map['slots'] as List<dynamic>).map((r) {
        final coords = (r as List<dynamic>).cast<num>();
        return CollageSlot(Rect.fromLTRB(
          coords[0].toDouble(),
          coords[1].toDouble(),
          coords[2].toDouble(),
          coords[3].toDouble(),
        ));
      }).toList();
      return CollageTemplate(
        id: map['id'] as String,
        name: map['name'] as String,
        icon: kCustomCollageIcon,
        slots: slots,
      );
    }).toList();
  } catch (_) {
    return [];
  }
}

/// Overwrites the custom-templates file with the given list.
Future<void> saveCustomCollageTemplates(List<CollageTemplate> templates) async {
  try {
    final file = await _customTemplatesFile();
    final data = templates
        .map((t) => {
              'id': t.id,
              'name': t.name,
              'slots': t.slots
                  .map((s) =>
                      [s.rect.left, s.rect.top, s.rect.right, s.rect.bottom])
                  .toList(),
            })
        .toList();
    await file.writeAsString(jsonEncode(data));
  } catch (_) {}
}
