import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:luma/features/plugins/plugin_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(entries.map((entry) => entry.id), ['smart-home', 'calculator']);
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
      expect(entries.map((entry) => entry.id), ['smart-home']);
      expect(entries.single.name, 'Smart Home');
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
    },
  );
}
