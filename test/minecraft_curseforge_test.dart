import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/minecraft_launcher/logic/content_api.dart';
import 'package:luma/features/plugins/installed/minecraft_launcher/logic/curseforge_api_client.dart';

void main() {
  group('CurseForge search hit', () {
    final hit = CurseForgeApiClient.hitFromJson({
      'id': 238222,
      'slug': 'jei',
      'name': "Just Enough Items (JEI)",
      'summary': 'View items and recipes',
      'downloadCount': 400000000,
      'thumbsUpCount': 1200,
      'classId': 6,
      'logo': {'thumbnailUrl': 'https://media.forgecdn.net/jei.png'},
      'authors': [
        {'name': 'mezz'},
      ],
      'categories': [
        {'slug': 'utility-qol', 'name': 'Utility & QoL'},
      ],
      'screenshots': [
        {'url': 'https://media.forgecdn.net/shot.png'},
      ],
      'latestFilesIndexes': [
        {'gameVersion': '1.20.1', 'modLoader': 1},
        {'gameVersion': '1.20.1', 'modLoader': 4},
      ],
      'dateModified': '2026-01-02T03:04:05Z',
    });

    test('carries a cf: prefixed id so the source is known from the id', () {
      expect(hit.projectId, 'cf:238222');
      expect(ContentSource.ofId(hit.projectId), ContentSource.curseforge);
      expect(ContentSource.ofId('AANobbMI'), ContentSource.modrinth);
    });

    test('maps the card fields', () {
      expect(hit.title, 'Just Enough Items (JEI)');
      expect(hit.projectType, 'mod');
      expect(hit.author, 'mezz');
      expect(hit.iconUrl, 'https://media.forgecdn.net/jei.png');
      expect(hit.displayCategories, ['utility-qol']);
      expect(hit.gameVersions, ['1.20.1']);
      expect(hit.featuredGallery, 'https://media.forgecdn.net/shot.png');
    });
  });

  group('CurseForge file as a version', () {
    Map<String, dynamic> file({String? downloadUrl}) => {
          'id': 5000001,
          'modId': 238222,
          'displayName': 'jei-1.20.1-15.2.0',
          'fileName': 'jei-1.20.1-forge-15.2.0.jar',
          'releaseType': 2,
          'fileDate': '2026-03-04T00:00:00Z',
          'fileLength': 1234,
          'downloadCount': 99,
          'downloadUrl': downloadUrl,
          'gameVersions': ['1.20.1', 'Forge', 'NeoForge', 'Client'],
          'hashes': [
            {'value': 'md5hash', 'algo': 2},
            {'value': 'sha1hash', 'algo': 1},
          ],
          'dependencies': [
            {'modId': 1, 'relationType': 3},
            {'modId': 2, 'relationType': 5},
            {'modId': 3, 'relationType': 2},
          ],
        };

    test('maps ids, channel, tags and the sha1 hash', () {
      final v = CurseForgeApiClient.versionFromJson(file(downloadUrl: 'https://edge.forgecdn.net/x.jar'));
      expect(v.id, 'cf:5000001');
      expect(v.projectId, 'cf:238222');
      expect(v.versionType, 'beta');
      expect(v.gameVersions, ['1.20.1']);
      expect(v.loaders, ['forge', 'neoforge']);
      expect(v.primaryFile.sha1, 'sha1hash');
      expect(v.primaryFile.url, 'https://edge.forgecdn.net/x.jar');
      expect(v.primaryFile.filename, 'jei-1.20.1-forge-15.2.0.jar');
    });

    test('maps relation types onto Modrinth dependency kinds', () {
      final deps = CurseForgeApiClient.versionFromJson(file()).dependencies;
      expect(deps.map((d) => (d.projectId, d.dependencyType)), [
        ('cf:1', 'required'),
        ('cf:2', 'incompatible'),
        ('cf:3', 'optional'),
      ]);
    });

    test('a file the author keeps off third-party launchers has no url', () {
      expect(CurseForgeApiClient.versionFromJson(file()).primaryFile.url, isEmpty);
    });
  });

  test('project page url falls back to the curseforge.com section', () {
    final project = CurseForgeApiClient.projectFromJson({
      'id': 1,
      'slug': 'faithful',
      'name': 'Faithful',
      'classId': 12,
    });
    expect(project.projectType, 'resourcepack');
    expect(
      ContentApi.projectPageUrl(project),
      'https://www.curseforge.com/minecraft/texture-packs/faithful',
    );
  });

  test('description HTML becomes Markdown the page renderer reads', () {
    final md = CurseForgeApiClient.htmlToMarkdown(
      '<h2>Features</h2><ul><li>Fast</li><li>Small &amp; light</li></ul><p>Done.</p>',
    );
    expect(md, '## Features\n\n- Fast\n- Small & light\n\nDone.');
  });
}
