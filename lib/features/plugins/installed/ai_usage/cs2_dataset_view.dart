import 'dart:async';
import 'dart:io';

import 'package:cs2_dataset/cs2_dataset.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../sync/sync_scope.dart';
import '../../../../sync/sync_service.dart';
import '../../../converter/file_saver.dart';
import 'cs2_dataset_repository.dart';

class Cs2DatasetView extends StatefulWidget {
  const Cs2DatasetView({super.key});

  @override
  State<Cs2DatasetView> createState() => _Cs2DatasetViewState();
}

class _Cs2DatasetViewState extends State<Cs2DatasetView> {
  SyncService? _sync;
  (String, bool)? _account;
  Cs2DatasetRepository? _repo;
  var _publishedMaps = <String, int>{};
  var _canDownload = false;
  var _personal = false;
  var _busy = false;
  var _loading = true;
  var _offline = false;
  var _map = 'de_mirage';
  var _revision = 0;
  Cs2Outcome? _previous;
  Cs2Prediction? _prediction;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sync = SyncScope.maybeOf(context);
    if (_sync != sync) {
      _sync?.removeListener(_accountChanged);
      _sync = sync;
      _sync?.addListener(_accountChanged);
    }
    _accountChanged();
  }

  @override
  void dispose() {
    _sync?.removeListener(_accountChanged);
    super.dispose();
  }

  void _accountChanged() {
    final account = (
      Cs2DatasetRepository.identity(_sync),
      _sync?.serverReady == true,
    );
    if (account == _account) return;
    _account = account;
    _load();
  }

  Future<void> _load() async {
    final l = L.of(context);
    final revision = ++_revision;
    setState(() {
      _repo = null;
      _loading = true;
      _busy = false;
      _prediction = null;
      _publishedMaps = {};
      _canDownload = false;
      _error = null;
    });
    try {
      final repo = await Cs2DatasetRepository.open(_sync);
      if (!mounted || revision != _revision) return;
      _repo = repo;
      if (repo.online) unawaited(_loadCatalog(repo));
      await _refresh();
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _error = l.cs2DatasetOpenFailed;
        _loading = false;
      });
    }
  }

  Future<void> _loadCatalog(Cs2DatasetRepository repo) async {
    try {
      final catalog = await repo.catalog();
      if (!mounted || _repo != repo) return;
      setState(() {
        _publishedMaps = catalog.maps;
        _canDownload = catalog.canDownload;
      });
    } catch (_) {
      // Local databases and predictions load independently of the catalog.
    }
  }

  Future<void> _refresh() async {
    final repo = _repo;
    if (repo == null) return;
    final revision = ++_revision;
    final map = _map;
    final previous = _previous;
    final l = L.of(context);
    setState(() {
      _loading = true;
      _offline = false;
      _prediction = null;
      _error = null;
    });
    Cs2Prediction? prediction;
    var offline = false;
    String? error;
    if (cs2BombMapId(map) != null) {
      if (_personal) {
        prediction = repo.personal.predict(map, previous);
      } else {
        if (repo.online) {
          try {
            prediction = await repo.prediction(map, previous);
          } catch (_) {
            error = l.cs2DatasetLoadFailed;
          }
        } else {
          error = l.cs2DatasetSignIn;
        }
        final downloaded = repo.downloaded;
        if (prediction == null && downloaded != null) {
          prediction = downloaded.predict(map, previous);
          offline = true;
          error = null;
        }
      }
    }
    if (!mounted || revision != _revision) return;
    setState(() {
      _loading = false;
      _offline = offline;
      _prediction = prediction;
      _error = error;
    });
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _run(
    Future<void> Function(Cs2DatasetRepository repo) action,
  ) async {
    final repo = _repo;
    if (repo == null || _busy) return;
    final l = L.of(context);
    setState(() => _busy = true);
    try {
      await action(repo);
    } on Cs2DatasetRequestException catch (error) {
      if (mounted && _repo == repo) _notice(error.message);
    } catch (_) {
      if (mounted && _repo == repo) _notice(l.cs2DatasetActionFailed);
    } finally {
      if (mounted && _repo == repo) setState(() => _busy = false);
    }
  }

  void _save(Cs2DatasetRepository repo, Cs2MatchInput input) {
    if (!mounted || _repo != repo) return;
    final l = L.of(context);
    final added = repo.save(input);
    setState(() {
      _map = input.match.map;
      _previous = null;
      _personal = true;
    });
    _refresh();
    _notice(added ? l.cs2DatasetRoundsSaved : l.cs2DatasetReplayDuplicate);
  }

  Future<void> _addManually() async {
    final repo = _repo;
    if (repo == null || _busy) return;
    final match = await showDialog<Cs2Match>(
      context: context,
      builder: (context) => _Cs2RoundEntry(initialMap: _map),
    );
    if (match == null || !mounted || _repo != repo) return;
    await _run((repo) async => _save(repo, Cs2MatchInput(match)));
  }

  Future<void> _upload() => _run((repo) async {
    final l = L.of(context);
    final pick = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['dem', 'bz2'],
      withData: false,
      withReadStream: true,
    );
    final file = pick?.files.single;
    if (file == null || !mounted || _repo != repo) return;
    final name = file.name.toLowerCase();
    if ((!name.endsWith('.dem') && !name.endsWith('.dem.bz2')) ||
        file.size > cs2MaxReplayBytes) {
      _notice(l.cs2DatasetReplayFormats);
      return;
    }
    final stream = file.readStream ?? File(file.path!).openRead();
    final match = await repo.importReplay(
      name: name.endsWith('.bz2') ? 'replay.dem.bz2' : 'replay.dem',
      size: file.size,
      data: stream,
    );
    _save(repo, match);
  });

  Future<void> _download() => _run((repo) async {
    await repo.download();
    if (mounted && _repo == repo) _notice(L.of(context).cs2DatasetDownloaded);
  });

  Future<void> _export() => _run((repo) async {
    final result = await saveConvertedFile(
      bytes: repo.downloadedBytes(),
      suggestedName: 'luma-cs2-database.json',
      mimeType: 'application/json',
      extensions: const ['json'],
    );
    if (mounted && _repo == repo && result.saved) _notice(result.summary);
  });

  List<String> get _maps => ({
    ...cs2Maps.keys,
    ..._publishedMaps.keys,
    ...?_repo?.downloaded?.maps,
    ...?_repo?.personal.maps,
    _map,
  }.toList()..sort((a, b) => cs2MapName(a).compareTo(cs2MapName(b))));

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final inset = context.isPhoneWidth ? 16.0 : 28.0;
    final canEdit = _repo != null && !_busy;
    final prediction = _prediction;
    return Scaffold(
      appBar: AppBar(title: Text('CS2 · ${l.aiUsageSectionDatasets}')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(inset, 12, inset, 28),
        children: [
          Align(
            alignment: AlignmentDirectional.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.cs2DatasetSubtitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(l.cs2DatasetDescription),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(l.cs2DatasetPublished),
                        selected: !_personal,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() => _personal = false);
                          _refresh();
                        },
                      ),
                      ChoiceChip(
                        label: Text(l.cs2DatasetPrivate),
                        selected: _personal,
                        onSelected: (selected) {
                          if (!selected) return;
                          setState(() => _personal = true);
                          _refresh();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_map),
                    initialValue: _map,
                    isExpanded: true,
                    menuMaxHeight: 420,
                    decoration: InputDecoration(labelText: l.cs2DatasetMap),
                    items: [
                      for (final map in _maps)
                        DropdownMenuItem(
                          value: map,
                          child: Text(
                            cs2MapName(map),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _map = value;
                        _previous = null;
                      });
                      _refresh();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey(_previous),
                    initialValue: _previous?.index ?? -1,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l.cs2DatasetPrevious,
                    ),
                    items: [
                      DropdownMenuItem(value: -1, child: Text(l.cs2DatasetAny)),
                      for (final outcome in Cs2Outcome.values)
                        DropdownMenuItem(
                          value: outcome.index,
                          child: Text(_outcomeLabel(l, outcome)),
                        ),
                    ],
                    onChanged: cs2BombMapId(_map) == null
                        ? null
                        : (value) {
                            setState(
                              () => _previous = value == null || value < 0
                                  ? null
                                  : Cs2Outcome.values[value],
                            );
                            _refresh();
                          },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l.cs2DatasetNext,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          if (_loading)
                            const LinearProgressIndicator()
                          else if (_error case final error?) ...[
                            Text(error),
                            if (_repo?.online == true || _repo == null)
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton(
                                  onPressed: _load,
                                  child: Text(l.cs2DatasetRetry),
                                ),
                              ),
                          ] else if (cs2BombMapId(_map) == null)
                            Text(l.cs2DatasetNoSites)
                          else if (prediction == null ||
                              prediction.sampleSize == 0)
                            Text(l.cs2DatasetNoRounds)
                          else ...[
                            if (_offline) Text(l.cs2DatasetOffline),
                            if (_previous != null && !prediction.conditioned)
                              Text(l.cs2DatasetFallback),
                            Text(l.cs2DatasetSample(prediction.sampleSize)),
                            const SizedBox(height: 8),
                            for (final outcome in prediction.ranking)
                              _ProbabilityRow(
                                label: _outcomeLabel(l, outcome),
                                chance:
                                    prediction.counts[outcome.index] /
                                    prediction.sampleSize,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_personal) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: canEdit ? _addManually : null,
                          icon: const Icon(Icons.add),
                          label: Text(l.cs2DatasetManual),
                        ),
                        OutlinedButton.icon(
                          onPressed: canEdit && _repo!.online ? _upload : null,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(l.cs2DatasetUpload),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l.cs2DatasetReplayPrivacy),
                    if (_repo?.online == false) Text(l.cs2DatasetReplaySignIn),
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_canDownload && _publishedMaps.isNotEmpty)
                          FilledButton.icon(
                            onPressed: canEdit ? _download : null,
                            icon: const Icon(Icons.download),
                            label: Text(l.cs2DatasetDownload),
                          ),
                        if (_repo?.downloaded != null)
                          OutlinedButton.icon(
                            onPressed: canEdit ? _export : null,
                            icon: const Icon(Icons.save_alt),
                            label: Text(l.cs2DatasetExport),
                          ),
                      ],
                    ),
                    if (!_canDownload && _publishedMaps.isNotEmpty)
                      Text(l.cs2DatasetPaidDownload),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _outcomeLabel(L l, Cs2Outcome outcome) => switch (outcome) {
  Cs2Outcome.a => l.cs2DatasetSiteA,
  Cs2Outcome.b => l.cs2DatasetSiteB,
  Cs2Outcome.other => l.cs2DatasetOther,
};

class _ProbabilityRow extends StatelessWidget {
  const _ProbabilityRow({required this.label, required this.chance});

  final String label;
  final double chance;

  @override
  Widget build(BuildContext context) {
    final percent = '${(chance * 100).toStringAsFixed(1)}%';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(percent),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: chance),
        ],
      ),
    );
  }
}

class _Cs2RoundEntry extends StatefulWidget {
  const _Cs2RoundEntry({required this.initialMap});

  final String initialMap;

  @override
  State<_Cs2RoundEntry> createState() => _Cs2RoundEntryState();
}

class _Cs2RoundEntryState extends State<_Cs2RoundEntry> {
  final _form = GlobalKey<FormState>();
  late final _map = TextEditingController(
    text: cs2BombMapId(widget.initialMap) ?? '',
  );
  final _rounds = TextEditingController();

  @override
  void dispose() {
    _map.dispose();
    _rounds.dispose();
    super.dispose();
  }

  List<Cs2Outcome?> _outcomes(String raw) => raw
      .toLowerCase()
      .split(RegExp(r'[\s,]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => Cs2Outcome.values.asNameMap()[part])
      .toList();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return AlertDialog(
      title: Text(l.cs2DatasetManual),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.cs2DatasetManualHelp),
            const SizedBox(height: 12),
            TextFormField(
              controller: _map,
              decoration: InputDecoration(
                labelText: l.cs2DatasetMapId,
                hintText: 'de_mirage',
              ),
              validator: (value) => cs2BombMapId(value ?? '') == null
                  ? l.cs2DatasetInvalidMap
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rounds,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l.cs2DatasetRounds,
                hintText: 'A, B, Other, A',
              ),
              validator: (value) {
                final outcomes = _outcomes(value ?? '');
                return outcomes.isEmpty ||
                        outcomes.length > cs2MaxManualRounds ||
                        outcomes.contains(null)
                    ? l.cs2DatasetInvalidRounds
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.of(context).pop(
              Cs2Match(cs2BombMapId(_map.text)!, [
                _outcomes(_rounds.text).cast<Cs2Outcome>(),
              ]),
            );
          },
          child: Text(l.cs2DatasetSave),
        ),
      ],
    );
  }
}
