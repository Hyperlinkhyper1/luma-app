import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:luma/features/plugins/plugin_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'stale remote metadata uses bundled translations and keeps remote updates',
    () async {
      final service = PluginCatalogService(
        get: (uri) async => http.Response(
          jsonEncode(
            uri.path.endsWith('registry.json')
                ? {
                    'plugins': [
                      {
                        'id': 'calculator',
                        'name': 'Calculator',
                        'description': 'Old English description',
                        'icon': 'calculate',
                        'category': 'Utility',
                        'i18n': {
                          'nl': {'name': 'Updated Dutch name'},
                        },
                      },
                    ],
                  }
                : {'name': 'Calculator', 'details': 'Old English details'},
          ),
          200,
        ),
      );
      final entry = (await service.fetchCatalog()).singleWhere(
        (entry) => entry.id == 'calculator',
      );
      expect(entry.nameIn('nl'), 'Updated Dutch name');
      for (final locale in ['nl', 'es', 'fr', 'zh']) {
        expect(entry.descriptionIn(locale), isNot('Old English description'));
        expect(entry.nameIn(locale), isNotEmpty);
      }
      final manifest = await service.fetchManifest('calculator');
      for (final locale in ['nl', 'es', 'fr', 'zh']) {
        expect(manifest.detailsIn(locale), isNot('Old English details'));
        expect(manifest.detailsIn(locale), isNotEmpty);
      }
    },
  );

  test(
    'Smart Home appears when the published catalog has not caught up',
    () async {
      final service = PluginCatalogService(
        get: (_) async => http.Response(
          jsonEncode({
            'plugins': [
              {
                'id': 'calculator',
                'name': 'Calculator',
                'icon': 'calculate',
                'category': 'Utility',
              },
            ],
          }),
          200,
        ),
      );

      final entries = await service.fetchCatalog();
      expect(entries.map((entry) => entry.id), [
        'smart-home',
        'small-games',
        'calculator',
      ]);
    },
  );

  test(
    'published Smart Home metadata does not create a duplicate tile',
    () async {
      final service = PluginCatalogService(
        get: (_) async => http.Response(
          jsonEncode({
            'plugins': [
              {
                'id': 'smart-home',
                'name': 'Older Smart Home',
                'icon': 'extension',
                'category': 'Utility',
              },
            ],
          }),
          200,
        ),
      );

      final entries = await service.fetchCatalog();
      expect(entries.map((entry) => entry.id), ['smart-home', 'small-games']);
      expect(entries.first.name, 'Smart Home');
    },
  );

  test(
    'Smart Home can be installed before its manifest is published',
    () async {
      final service = PluginCatalogService(
        get: (_) async => http.Response('Not Found', 404),
      );

      final manifest = await service.fetchManifest('smart-home');
      expect(manifest.name, 'Smart Home');
      final games = await service.fetchManifest('small-games');
      expect(games.name, 'Small Games');
    },
  );
}
