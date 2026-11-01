import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:luma_sync_server/fish_library.dart';
import 'package:luma_sync_server/fish_species_file.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// A tiny stand-in for the GitHub Git Data API over an in-memory repository:
/// enough of refs, trees, blobs and commits for FishLibrary.
class FakeGithub {
  FakeGithub(Map<String, String> files) {
    _commit(files, 'initial');
  }

  final Map<String, String> blobs = {};
  final Map<String, Map<String, String>> trees = {};
  final Map<String, ({String tree, String message})> commits = {};
  late String head;
  final List<String> calls = [];

  String _sha(String text) => sha1.convert(utf8.encode(text)).toString();

  String _tree(Map<String, String> files) {
    final shas = {for (final e in files.entries) e.key: _blob(e.value)};
    final sha = _sha(jsonEncode(shas));
    trees[sha] = shas;
    return sha;
  }

  String _blob(String text) {
    final sha = _sha('blob:$text');
    blobs[sha] = text;
    return sha;
  }

  void _commit(Map<String, String> files, String message) {
    final tree = _tree(files);
    final sha = _sha('commit:$tree:$message:${commits.length}');
    commits[sha] = (tree: tree, message: message);
    head = sha;
  }

  Map<String, String> get files => {
        for (final e in trees[commits[head]!.tree]!.entries) e.key: blobs[e.value]!,
      };

  /// Someone else pushing to the branch.
  void push(Map<String, String> changes) =>
      _commit({...files, ...changes}, 'outside push');

  Future<({int status, String body})> call(
      String method, Uri url, Map<String, String> headers, String? body) async {
    final path = url.path.replaceFirst(RegExp(r'^/repos/[^/]+/[^/]+'), '');
    calls.add('$method $path');
    ({int status, String body}) ok(Object json) =>
        (status: 200, body: jsonEncode(json));
    final input = body == null ? null : jsonDecode(body) as Map<String, dynamic>;
    if (method == 'GET' && path == '/git/ref/heads/master') {
      return ok({'object': {'sha': head}});
    }
    if (method == 'GET' && path.startsWith('/git/trees/')) {
      final commit = commits[path.substring('/git/trees/'.length)]!;
      return ok({
        'tree': [
          for (final e in trees[commit.tree]!.entries)
            {'path': e.key, 'type': 'blob', 'sha': e.value},
        ],
      });
    }
    if (method == 'GET' && path.startsWith('/git/blobs/')) {
      final text = blobs[path.substring('/git/blobs/'.length)];
      if (text == null) return (status: 404, body: '{"message":"Not Found"}');
      return ok({'content': base64.encode(utf8.encode(text)), 'encoding': 'base64'});
    }
    if (method == 'GET' && path.startsWith('/git/commits/')) {
      return ok({'tree': {'sha': commits[path.substring('/git/commits/'.length)]!.tree}});
    }
    if (method == 'POST' && path == '/git/blobs') {
      return ok({'sha': _blob(input!['content'] as String)});
    }
    if (method == 'POST' && path == '/git/trees') {
      final base = Map<String, String>.from(trees[input!['base_tree']]!);
      for (final entry in (input['tree'] as List).cast<Map>()) {
        base[entry['path'] as String] = entry['sha'] as String;
      }
      final sha = _sha(jsonEncode(base));
      trees[sha] = base;
      return ok({'sha': sha});
    }
    if (method == 'POST' && path == '/git/commits') {
      final sha = _sha('commit:${input!['tree']}:${input['message']}:${commits.length}');
      commits[sha] = (tree: input['tree'] as String, message: input['message'] as String);
      pending[sha] = (input['parents'] as List).first as String;
      return ok({'sha': sha});
    }
    if (method == 'PATCH' && path == '/git/refs/heads/master') {
      final sha = input!['sha'] as String;
      if (pending[sha] != head) {
        return (status: 422, body: '{"message":"Update is not a fast forward"}');
      }
      head = sha;
      return ok({'object': {'sha': sha}});
    }
    return (status: 404, body: '{"message":"Not Found"}');
  }

  final Map<String, String> pending = {};
}

const _trout = '''return {
	Name = "Trout",
	Rarity = "Common",
	RarityDenominator = 4,
	MinKg = 0.3,
	AverageKg = 1.2,
	MaxKg = 9,
	BaseValue = 10,
	Fight = 0.04,
	Pools = { "MainLake" },
	Seasons = { "Summer" },
	Shapes = {
		Normal = { "##" },
		Big = { "###" },
		Huge = { "###", "###" },
	},
	Build = function(b, kit)
		local rgb = kit.rgb
		b:fishBody(0.21, 0.12, { back = rgb(78, 90, 54), side = rgb(184, 188, 160), belly = rgb(240, 236, 224) })
	end,
}
''';

const _shark = '''return {
	Name = "Shark Meat",
	Rarity = "Common",
	RarityDenominator = 1 / 0.60,
	MinKg = 1,
	AverageKg = 1,
	MaxKg = 1,
	BaseValue = 35,
	Fight = 0,
	DropOnly = true,
	Shapes = {
		Normal = { "#" },
	},
}
''';

const _catalog = '''local JUNK = { "WoodenBranch" }
Catalog.Pools = {
	MainLake = { Name = "Main Lake", Area = "lake", Junk = JUNK },
	OpenSea = { Name = "Open Sea", Area = "open", Junk = JUNK },
	CoralShallows = { Name = "Coral Shallows", Area = "tropical", Inherits = "OpenSea", Junk = JUNK },
}
''';

Map<String, String> _syntheticRepo() => {
      'src/shared/AnglerCatalog.luau': _catalog,
      'src/shared/FishSpecies.luau': '-- format docs\nreturn {}\n',
      'src/shared/FishModels.luau':
          'local Builder = {}\nfunction Builder:fishBody() end\nlocal kit = {\n\trgb = rgb,\n}\n',
      'src/shared/FishMutations.luau': 'return {}\n',
      'src/shared/Fish/Trout.luau': _trout,
      'src/shared/Fish/SharkMeat.luau': _shark,
      'README.md': 'game',
    };

Request _get(String path) => Request('GET', Uri.parse('http://localhost$path'));
Request _post(String path, Object body) => Request(
    'POST', Uri.parse('http://localhost$path'),
    body: jsonEncode(body), headers: {'content-type': 'application/json'});

Future<Map<String, dynamic>> _json(FutureOr<Response> response) async =>
    jsonDecode(await (await response).readAsString()) as Map<String, dynamic>;

Future<FishJob?> _settle(FishLibrary library, String id) async {
  for (var i = 0; i < 600; i++) {
    final job = await _json(library.job(_get('/'), id));
    if (!const {'queued', 'generating', 'previewing', 'committing'}
        .contains(job['status'])) {
      return null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('job $id never finished');
}

String _reply(String module) =>
    jsonEncode({
      'choices': [
        {'message': {'content': 'Here you go.\n```lua\n$module```\nShort note.'}},
      ],
      'usage': {'prompt_tokens': 100, 'completion_tokens': 50},
    });

void main() {
  late Directory dir;
  late FakeGithub github;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('luma_fish_library_test');
    github = FakeGithub(_syntheticRepo());
  });
  tearDown(() => dir.delete(recursive: true));

  FishLibrary library({
    List<String>? replies,
    List<String>? prompts,
    LuauRunner? luau,
    String? token = 'gh-token',
    String? wikiDir,
  }) {
    final queue = [...?replies];
    // Previews read the wiki's Roblox mock and exporter; the fake runner
    // never executes them.
    final wiki = wikiDir ?? '${dir.path}/wiki';
    final mocks = Directory('$wiki/source/scripts/fish-models')..createSync(recursive: true);
    for (final name in ['roblox-mock.luau', 'export.luau']) {
      File('${mocks.path}/$name').writeAsStringSync('-- $name\n');
    }
    return FishLibrary(
      dataDir: dir.path,
      wikiDir: wiki,
      environment: {
        if (token != null) 'LUMA_FISHING_WATERS_GITHUB_TOKEN': token,
      },
      github: github.call,
      aiKey: (u) => u == AiUpstream.openrouter ? 'or-key' : null,
      ai: (url, headers, body) async {
        prompts?.add(body);
        if (queue.isEmpty) return (status: 500, body: '{"error":"no reply"}');
        return (status: 200, body: _reply(queue.removeAt(0)));
      },
      luau: luau ??
          (source) async => (
                code: 0,
                stdout: 'FISHCHECK 1\n${jsonEncode(_fakeExport(source))}\n',
                stderr: '',
              ),
    );
  }

  group('species files', () {
    test('parse data lines, including divided odds', () {
      final trout = FishSpeciesFile('Trout', _trout).toJson();
      expect(trout['rarity'], 'Common');
      expect(trout['odds'], 4);
      expect(trout['pools'], ['MainLake']);
      expect(trout['seasons'], ['Summer']);
      expect(trout['requires'], isEmpty);
      expect(trout['hasBuild'], isTrue);
      final shark = FishSpeciesFile('SharkMeat', _shark).toJson();
      expect(shark['odds'], closeTo(1 / 0.6, 1e-9));
      expect(shark['dropOnly'], isTrue);
      expect(shark['hasBuild'], isFalse);
    });

    test('rewrite, insert and remove fields in module order', () {
      final edited = FishSpeciesFile('Trout', _trout).withFields({
        'Rarity': 'Rare',
        'Requires': ['Rain', 'Night'],
        'Seasons': <String>[],
        'MaxKg': 12.5,
      });
      final lines = edited.source.split('\n');
      expect(lines, contains('\tRarity = "Rare",'));
      expect(lines, contains('\tMaxKg = 12.5,'));
      expect(edited.source, isNot(contains('Seasons')));
      expect(lines.indexOf('\tRequires = { "Rain", "Night" },'),
          lines.indexOf('\tPools = { "MainLake" },') + 1);
      expect(edited.source, contains('Build = function'));
    });

    test('refuse modules that reach outside their Build', () {
      expect(forbiddenIdentifier(_trout), isNull);
      expect(forbiddenIdentifier('local x = require(123)'), 'require');
      expect(forbiddenIdentifier('game:GetService("HttpService")'), 'game');
      expect(forbiddenIdentifier('-- require(1)\nlocal s = "game"'), isNull);
      expect(forbiddenIdentifier('b:wait() p.task = 1'), isNull);
      expect(forbiddenIdentifier('getfenv(0)'), 'getfenv');
    });

    test('flag impossible conditions and bad data', () {
      final pools = {'MainLake', 'OpenSea'};
      FishSpeciesFile edit(Map<String, Object?> f) =>
          FishSpeciesFile('Trout', _trout).withFields(f);
      expect(edit({}).problem(pools), isNull);
      expect(edit({'Requires': ['Day', 'Night']}).problem(pools), contains('day and night'));
      expect(edit({'Requires': ['Rain', 'Clear']}).problem(pools), isNotNull);
      expect(edit({'MinKg': 20}).problem(pools), contains('MinKg'));
      expect(edit({'Pools': ['Moon']}).problem(pools), contains('Unknown pool'));
      expect(edit({'Rarity': 'Mythic'}).problem(pools), contains('Rarity'));
    });

    test('names become ids and slugs', () {
      expect(fishIdFromName('ember snapper'), 'EmberSnapper');
      expect(fishIdFromName('!!'), isNull);
      expect(fishSlug('GreatWhiteTooth'), 'great-white-tooth');
    });
  });

  test('the library lists species, pools and what may be edited', () async {
    final json = await _json(library().library(_get('/admin/fishing-waters/fish')));
    expect(json['canCommit'], isTrue);
    expect((json['pools'] as List).map((p) => p['id']),
        ['MainLake', 'OpenSea', 'CoralShallows']);
    expect((json['pools'] as List).last['inherits'], 'OpenSea');
    final fish = {for (final f in json['fish'] as List) f['id']: f};
    expect(fish.keys, containsAll(['Trout', 'SharkMeat']));
    expect(fish['Trout']['seasons'], ['Summer']);
  });

  test('a repo still on the single-file layout says so', () async {
    github = FakeGithub({'src/shared/AnglerCatalog.luau': _catalog});
    final json = await _json(library().library(_get('/')));
    expect(json['fish'], isEmpty);
    expect(json['problem'], contains('src/shared/Fish'));
  });

  test('quick edits commit one rewritten module', () async {
    final lib = library();
    final json = await _json(lib.quickEdit(
        _post('/', {
          'changes': {
            'rarity': 'Uncommon',
            'value': 22,
            'seasons': ['Winter', 'Spring'],
            'requires': ['Storm', 'Night'],
            'pools': ['MainLake', 'CoralShallows'],
          },
        }),
        'Trout'));
    expect(json['commit'], contains('/commit/'));
    final file = github.files['src/shared/Fish/Trout.luau']!;
    expect(file, contains('\tRarity = "Uncommon",'));
    expect(file, contains('\tBaseValue = 22,'));
    expect(file, contains('\tSeasons = { "Spring", "Winter" },'));
    expect(file, contains('\tRequires = { "Storm", "Night" },'));
    expect(file, contains('\tPools = { "MainLake", "CoralShallows" },'));
    expect(github.files['src/shared/Fish/SharkMeat.luau'], _shark);
    expect(github.commits[github.head]!.message, startsWith('Fish library: Trout'));

    final all = await _json(lib.quickEdit(
        _post('/', {'changes': {'seasons': ['Spring', 'Summer', 'Autumn', 'Winter']}}), 'Trout'));
    expect(all['fish']['seasons'], isEmpty);
    expect(github.files['src/shared/Fish/Trout.luau'], isNot(contains('Seasons')));
  });

  test('quick edits refuse bad values and need the token', () async {
    final lib = library();
    for (final changes in [
      {'minKg': 50},
      {'requires': ['Day', 'Night']},
      {'pools': ['Atlantis']},
      {'rarity': 'Mythic'},
      {'nope': 1},
    ]) {
      final response = await lib.quickEdit(_post('/', {'changes': changes}), 'Trout');
      expect(response.statusCode, 400, reason: '$changes');
    }
    expect(github.files['src/shared/Fish/Trout.luau'], _trout);
    final readOnly = await library(token: null)
        .quickEdit(_post('/', {'changes': {'value': 1}}), 'Trout');
    expect(readOnly.statusCode, 503);
  });

  test('a new fish is generated, previewed, approved and committed', () async {
    final wiki = Directory('${dir.path}/wiki')..createSync();
    final prompts = <String>[];
    final module = _trout
        .replaceFirst('"Trout"', '"Ember Snapper"')
        .replaceFirst('"Common"', '"Epic"')
        .replaceFirst('{ "MainLake" }', '{ "OpenSea" }');
    final lib = library(replies: [module], prompts: prompts, wikiDir: wiki.path);
    final created = await _json(lib.createJob(_post('/', {
      'mode': 'new',
      'provider': 'openrouter',
      'model': 'vendor/model',
      'effort': 'high',
      'prompt': 'Glowing orange fins.',
      'fields': {
        'name': 'Ember Snapper',
        'rarity': 'Rare',
        'seasons': ['Autumn'],
        'requires': ['Night'],
        'pools': ['CoralShallows'],
      },
    })));
    expect(created['fishId'], 'EmberSnapper');
    await _settle(lib, created['id'] as String);
    final job = await _json(lib.job(_get('/'), created['id'] as String));
    expect(job['status'], 'ready', reason: '${job['error']}');
    expect(job['hasPreview'], isTrue);
    // The chosen fields win over what the model wrote.
    expect(job['result'], contains('\tRarity = "Rare",'));
    expect(job['result'], contains('\tPools = { "CoralShallows" },'));
    expect(job['result'], contains('\tRequires = { "Night" },'));
    expect(job['result'], contains('\tSeasons = { "Autumn" },'));
    expect(job['notes'], contains('Short note'));
    final sent = jsonDecode(prompts.single) as Map;
    expect(sent['reasoning'], {'effort': 'high'});
    expect(jsonEncode(sent['messages']), contains('Glowing orange fins'));
    expect(jsonEncode(sent['messages']), contains('Coral Shallows'));

    final preview = await lib.preview(_get('/'), created['id'] as String);
    expect(jsonDecode(await preview.readAsString())['parts'], isNotEmpty);

    final approved = await _json(lib.approveJob(_post('/', {}), created['id'] as String));
    expect(approved['status'], 'committed');
    expect(github.files['src/shared/Fish/EmberSnapper.luau'], job['result']);
    expect(github.commits[github.head]!.message, startsWith('Add Ember Snapper'));
    expect(File('${dir.path}/fish_models/ember-snapper.json').existsSync(), isTrue);
    expect(File('${wiki.path}/.fish-refresh-request').existsSync(), isTrue);
  });

  test('a broken module goes back to the model with the error', () async {
    final prompts = <String>[];
    final bad = _trout.replaceFirst('local rgb = kit.rgb', 'local http = require(12345)\n\t\tlocal rgb = kit.rgb');
    final good = _trout.replaceFirst('BaseValue = 10', 'BaseValue = 12');
    final lib = library(replies: [bad, good], prompts: prompts);
    final created = await _json(lib.createJob(_post('/', {
      'mode': 'edit',
      'fishId': 'Trout',
      'provider': 'openrouter',
      'model': 'vendor/model',
      'effort': '',
      'prompt': 'Worth a bit more.',
    })));
    await _settle(lib, created['id'] as String);
    final job = await _json(lib.job(_get('/'), created['id'] as String));
    expect(job['status'], 'ready');
    expect(job['result'], contains('BaseValue = 12'));
    expect(prompts, hasLength(2));
    expect(prompts.last, contains('require'));
    expect(job['original'], _trout);
  });

  test('a failing preview is retried, then the job fails', () async {
    final lib = library(
        replies: [_trout, _trout, _trout],
        luau: (source) async => (code: 1, stdout: '', stderr: 'bundle:12: attempt to call a nil value'));
    final created = await _json(lib.createJob(_post('/', {
      'mode': 'edit', 'fishId': 'Trout', 'provider': 'openrouter',
      'model': 'm', 'effort': '', 'prompt': 'x',
    })));
    await _settle(lib, created['id'] as String);
    final job = await _json(lib.job(_get('/'), created['id'] as String));
    expect(job['status'], 'failed');
    expect(job['error'], contains('nil value'));
  });

  test('approving fails safely when the file changed on GitHub meanwhile', () async {
    final lib = library(replies: [_trout.replaceFirst('BaseValue = 10', 'BaseValue = 11')]);
    final created = await _json(lib.createJob(_post('/', {
      'mode': 'edit', 'fishId': 'Trout', 'provider': 'openrouter',
      'model': 'm', 'effort': '', 'prompt': 'x',
    })));
    await _settle(lib, created['id'] as String);
    github.push({'src/shared/Fish/Trout.luau': _trout.replaceFirst('BaseValue = 10', 'BaseValue = 99')});
    expect((await _json(lib.job(_get('/'), created['id'] as String)))['status'], 'ready');
    final response = await lib.approveJob(_post('/', {}), created['id'] as String);
    expect(response.statusCode, 409);
    expect((await _json(response))['error'], 'conflict');
    expect(github.files['src/shared/Fish/Trout.luau'], contains('BaseValue = 99'));
    // Unrelated pushes don't block a commit: it is rebuilt on the new head.
    github.push({'README.md': 'changed'});
    final quick = await lib.quickEdit(_post('/', {'changes': {'fight': 0.05}}), 'Trout');
    expect(quick.statusCode, 200);
    expect(github.files['README.md'], 'changed');
  });

  test('jobs need a provider with a key and a sane request', () async {
    final lib = library();
    Future<int> status(Map<String, Object?> body) async =>
        (await lib.createJob(_post('/', body))).statusCode;
    final base = {'mode': 'edit', 'fishId': 'Trout', 'provider': 'openrouter', 'model': 'm', 'effort': '', 'prompt': 'x'};
    expect(await status({...base, 'provider': 'google'}), 400);
    expect(await status({...base, 'model': 'bad model!'}), 400);
    expect(await status({...base, 'prompt': ''}), 400);
    expect(await status({...base, 'image': 'data:text/html;base64,AAAA'}), 400);
    expect(await status({'mode': 'new', 'provider': 'openrouter', 'model': 'm', 'effort': '',
        'fields': {'name': 'X Fish', 'pools': <String>[]}}), 400);
  });

  final game = Platform.environment['LUMA_TEST_FISHING_WATERS'] ??
      '${Directory.current.path}/../../Roblox Fishing Waters';
  final wikiSource = Platform.environment['LUMA_TEST_WIKI_SOURCE'] ??
      '${Directory.current.path}/../../Portofilio';
  final lute = Platform.environment['LUMA_TEST_LUTE'] ?? 'lute';
  final haveGame = Directory('$game/src/shared/Fish').existsSync() &&
      File('$wikiSource/scripts/fish-models/export.luau').existsSync();

  test('the real game builds a previewed species under lute', () async {
    final files = <String, String>{};
    for (final entity in Directory('$game/src/shared').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.luau')) {
        final rel = entity.path.substring(game.length + 1).replaceAll(r'\', '/');
        files[rel] = entity.readAsStringSync();
      }
    }
    github = FakeGithub(files);
    final wiki = Directory('${dir.path}/wiki/source/scripts/fish-models')..createSync(recursive: true);
    for (final name in ['roblox-mock.luau', 'export.luau']) {
      File('$wikiSource/scripts/fish-models/$name').copySync('${wiki.path}/$name');
    }
    // Every species in the game passes the module checks.
    final pools = {'MainLake', 'OpenSea', 'GullhavenSound', 'SoddenMire', 'CoralShallows', 'CinderIsles', 'FrostmereExpanse'};
    for (final e in files.entries.where((e) => e.key.startsWith('src/shared/Fish/'))) {
      final id = e.key.split('/').last.replaceAll('.luau', '');
      expect(FishSpeciesFile(id, e.value).problem(pools), isNull, reason: id);
    }
    final pike = files['src/shared/Fish/Pike.luau']!
        .replaceFirst('"Pike"', '"Lava Pike"')
        .replaceAll(RegExp(r'rgb\(\d+, \d+, \d+\)'), 'rgb(230, 90, 30)');
    final lib = FishLibrary(
      dataDir: dir.path,
      wikiDir: '${dir.path}/wiki',
      environment: const {'LUMA_FISHING_WATERS_GITHUB_TOKEN': 't'},
      github: github.call,
      aiKey: (_) => 'k',
      ai: (url, headers, body) async => (status: 200, body: _reply(pike)),
      luau: (source) async {
        final file = File('${dir.path}/bundle.luau')..writeAsStringSync(source);
        final run = await Process.run(lute, ['run', file.path]);
        return (code: run.exitCode, stdout: '${run.stdout}', stderr: '${run.stderr}');
      },
    );
    final created = await _json(lib.createJob(_post('/', {
      'mode': 'new', 'provider': 'openrouter', 'model': 'm', 'effort': '', 'prompt': '',
      'fields': {'name': 'Lava Pike', 'pools': ['CinderIsles'], 'requires': ['Clear', 'Day']},
    })));
    await _settle(lib, created['id'] as String);
    final job = await _json(lib.job(_get('/'), created['id'] as String));
    expect(job['status'], 'ready', reason: '${job['error']}');
    final model = jsonDecode(await (await lib.preview(_get('/'), created['id'] as String)).readAsString());
    expect(model['id'], 'LavaPike');
    expect((model['parts'] as List).length, greaterThan(20));
    expect((model['variants'] as Map).keys, containsAll(['Albino', 'Rainbow', 'Windy']));
    expect(jsonEncode(model['parts']), contains('#e65a1e'));
  }, skip: haveGame ? false : 'needs the game and wiki checkouts', timeout: const Timeout(Duration(minutes: 3)));
}

/// What the exporter would print for the bundle's one species: a single
/// block part, plus an Albino variant that repaints it.
Map<String, Object> _fakeExport(String bundle) {
  final id = RegExp(r'FishModels\.has\("(\w+)"\)').firstMatch(bundle)![1]!;
  Map<String, Object> part(String color) => {
        'n': 'Body', 's': 'sphere', 'z': [1, 0.4, 0.3], 'p': [0, 0, 0],
        'r': [[1, 0, 0], [0, 1, 0], [0, 0, 1]], 'c': color, 'm': 'SmoothPlastic',
      };
  Map<String, Object> model(String color) => {
        'parts': [part(color)], 'effects': <Object>[],
        'boundsCenter': [0, 0, 0], 'boundsSize': [1, 0.4, 0.3],
      };
  return {
    'id': id,
    'view': [0.18, 0.16, 1],
    'variants': {'Normal': model('#336699'), 'Albino': model('#f0f0f0')},
  };
}
