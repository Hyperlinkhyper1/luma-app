import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/minecraft_launcher/logic/mod_install_flow.dart';
import 'package:luma/features/plugins/installed/minecraft_launcher/logic/modrinth_api_client.dart';
import 'package:luma/features/plugins/installed/minecraft_launcher/ui/modrinth_ui.dart';

ModrinthVersion _version({
  required String id,
  required String type,
  required DateTime published,
}) =>
    ModrinthVersion.fromJson({
      'id': id,
      'project_id': 'p',
      'version_number': id,
      'name': id,
      'version_type': type,
      'game_versions': ['1.20.1'],
      'loaders': ['fabric'],
      'files': const [],
      'dependencies': const [],
      'date_published': published.toIso8601String(),
    });

void main() {
  group('search hit parsing', () {
    test('reads the card fields Modrinth returns', () {
      final hit = ModrinthSearchHit.fromJson({
        'project_id': 'AANobbMI',
        'slug': 'sodium',
        'title': 'Sodium',
        'description': 'A rendering engine replacement.',
        'icon_url': 'https://cdn.modrinth.com/sodium.png',
        'downloads': 225145802,
        'follows': 40000,
        'project_type': 'mod',
        'categories': ['optimization', 'fabric'],
        'display_categories': ['optimization'],
        'author': 'jellysquid3',
        'date_modified': '2026-01-02T03:04:05Z',
        'color': 0x30D46A,
        'client_side': 'required',
        'server_side': 'unsupported',
        'versions': ['1.20.1'],
      });

      expect(hit.author, 'jellysquid3');
      expect(hit.displayCategories, ['optimization']);
      expect(hit.dateModified, isNotNull);
      expect(modrinthAccentOf(hit.color)!.toARGB32(), 0xFF30D46A);
    });

    test('treats blank strings as absent rather than printing empties', () {
      final hit = ModrinthSearchHit.fromJson({
        'project_id': 'x',
        'title': 'X',
        'icon_url': '',
        'author': '   ',
      });
      expect(hit.iconUrl, isNull);
      expect(hit.author, isNull);
    });
  });

  group('project parsing', () {
    test('puts the featured gallery image first', () {
      final project = ModrinthProject.fromJson({
        'id': 'p',
        'slug': 'p',
        'title': 'P',
        'gallery': [
          {'url': 'b.png', 'featured': false, 'title': 'Second'},
          {'url': 'a.png', 'featured': true, 'title': 'Banner'},
        ],
        'categories': ['optimization'],
        'additional_categories': ['utility'],
        'license': {'id': 'LGPL-3.0', 'name': 'LGPL-3.0-only'},
      });

      expect(project.orderedGallery.first.url, 'a.png');
      expect(project.categories, ['optimization', 'utility']);
      expect(project.licenseName, 'LGPL-3.0-only');
    });
  });

  group('one-tap install version choice', () {
    test('prefers the newest release over a newer pre-release', () {
      final best = ModInstallFlow.bestVersion([
        _version(id: 'beta', type: 'beta', published: DateTime(2026, 3)),
        _version(id: 'release', type: 'release', published: DateTime(2026, 2)),
        _version(id: 'older', type: 'release', published: DateTime(2025, 1)),
      ]);
      expect(best!.id, 'release');
    });

    test('falls back to the newest build when nothing is a full release', () {
      final best = ModInstallFlow.bestVersion([
        _version(id: 'alpha-old', type: 'alpha', published: DateTime(2025, 1)),
        _version(id: 'alpha-new', type: 'alpha', published: DateTime(2026, 1)),
      ]);
      expect(best!.id, 'alpha-new');
    });

    test('returns null when the instance has no compatible build', () {
      expect(ModInstallFlow.bestVersion(const []), isNull);
    });
  });

  group('card formatting', () {
    test('compacts download counts the way Modrinth prints them', () {
      expect(formatCompactCount(254288940), '254.3M');
      expect(formatCompactCount(1500), '1.5K');
      expect(formatCompactCount(942), '942');
    });

    test('humanises category slugs', () {
      expect(prettyTag('game-mechanics'), 'Game mechanics');
      expect(prettyTag('worldgen'), 'Worldgen');
      expect(prettyTag(''), '');
    });

    test('describes how long ago a project was updated', () {
      expect(relativeTime(null), '');
      expect(
        relativeTime(DateTime.now().subtract(const Duration(days: 2))),
        '2 days ago',
      );
      expect(
        relativeTime(DateTime.now().subtract(const Duration(minutes: 5))),
        '5m ago',
      );
    });

    test('formats file sizes for the version list', () {
      expect(formatFileSize(2 * 1024 * 1024), '2.0 MB');
      expect(formatFileSize(2048), '2 KB');
    });
  });
}
