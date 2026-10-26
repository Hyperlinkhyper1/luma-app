import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../../app/widgets.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../theme/luma_theme.dart';
import 'ai_benchmark_scope.dart';
import 'decider_results.dart';
import 'tts_results.dart';

/// The localized title of one of the Text to Speech scripts.
String ttsScriptTitle(L t, String id) => switch (id) {
      'station_announcement' => t.aiTtsTestStation,
      'poem_female' => t.aiTtsTestPoemFemale,
      'poem_male' => t.aiTtsTestPoemMale,
      'speech_male' => t.aiTtsTestSpeechMale,
      _ => id,
    };

/// AI Usage → Tests → Text to Speech: every speech model the admin
/// dashboard ran through the four scripts, with what the four clips cost
/// and took. Tapping a model opens its clips to listen to.
class TtsTestPage extends StatefulWidget {
  const TtsTestPage({super.key});

  @override
  State<TtsTestPage> createState() => _TtsTestPageState();
}

class _TtsTestPageState extends State<TtsTestPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    AiBenchmarkScope.of(context).loadTts();
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final repo = AiBenchmarkScope.of(context);
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(t.aiTestTtsTitle),
        actions: [
          if (repo.canRefresh)
            IconButton(
              tooltip: t.commonRefresh,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: repo.ttsLoading ? null : repo.loadTts,
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final board = repo.tts;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                t.aiTtsIntro,
                style: TextStyle(color: luma.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (board == null && repo.ttsLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              else if (board == null || board.entries.isEmpty)
                LumaEmptyState(
                  icon: Icons.record_voice_over_rounded,
                  title: t.aiTtsEmpty,
                  subtitle: !repo.canRefresh
                      ? t.aiBenchmarkSignInToFetch
                      : repo.ttsError ??
                          (board != null && board.otherScripts > 0
                              ? t.aiTtsHidden('${board.otherScripts}')
                              : t.aiTtsEmptyDetail),
                )
              else
                for (final e in board.entries) ...[
                  _row(context, board, e),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, TtsBoard board, TtsEntry e) {
    final luma = context.luma;
    final t = L.of(context);
    final ok = e.clips.where((c) => c.ok).length;
    return LumaCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TtsModelPage(board: board, entry: e),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: deciderVendorColor(e.vendor),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.shortName,
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${e.vendor} · ${t.aiTtsModelLine(ttsMoney(e.costUsd), ttsSeconds(e.totalMs / 1000))}',
                      style: TextStyle(color: luma.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '$ok/${board.scripts.length}',
                style: TextStyle(
                  color: ok == board.scripts.length
                      ? luma.success
                      : luma.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: luma.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// One speech model's four clips, each with its play button, voice, cost,
/// how long it took to make and the text it read.
class TtsModelPage extends StatefulWidget {
  const TtsModelPage({super.key, required this.board, required this.entry});

  final TtsBoard board;
  final TtsEntry entry;

  @override
  State<TtsModelPage> createState() => _TtsModelPageState();
}

class _TtsModelPageState extends State<TtsModelPage> {
  /// Made on first play, so the page builds where no audio plugin exists.
  AudioPlayer? _player;
  StreamSubscription<void>? _done;
  String? _playing;
  String? _fetching;
  final Map<String, String> _errors = {};
  final Set<String> _showText = {};

  @override
  void dispose() {
    _done?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle(TtsClipInfo clip) async {
    if (_playing == clip.test) {
      await _player?.pause();
      setState(() => _playing = null);
      return;
    }
    final repo = AiBenchmarkScope.of(context);
    setState(() {
      _fetching = clip.test;
      _errors.remove(clip.test);
    });
    try {
      final file = await repo.ttsClipFile(
          widget.entry.runId, clip.test, clip.format ?? 'mp3');
      final player = _player ??= AudioPlayer();
      _done ??= player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playing = null);
      });
      await player.stop();
      await player.play(DeviceFileSource(
        file.path,
        mimeType: clip.format == 'wav' ? 'audio/wav' : 'audio/mpeg',
      ));
      if (mounted) setState(() => _playing = clip.test);
    } catch (e) {
      if (mounted) setState(() => _errors[clip.test] = '$e');
    } finally {
      if (mounted) setState(() => _fetching = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final e = widget.entry;
    return Scaffold(
      backgroundColor: luma.background,
      appBar: AppBar(
        backgroundColor: luma.background,
        elevation: 0,
        title: Text(e.shortName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '${e.model} · ${t.aiTtsModelLine(ttsMoney(e.costUsd), ttsSeconds(e.totalMs / 1000))}',
            style: TextStyle(color: luma.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          for (final script in widget.board.scripts) ...[
            _clipCard(context, script, e.clip(script.id)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _clipCard(BuildContext context, TtsScript script, TtsClipInfo? clip) {
    final luma = context.luma;
    final t = L.of(context);
    final ok = clip != null && clip.ok;
    final playing = _playing == script.id;
    final fetching = _fetching == script.id;
    final textOpen = _showText.contains(script.id);
    final error = _errors[script.id];
    return LumaCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: fetching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : IconButton.filledTonal(
                        tooltip: playing ? t.aiTtsPause : t.aiTtsPlay,
                        onPressed: ok ? () => _toggle(clip) : null,
                        icon: Icon(playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ttsScriptTitle(t, script.id),
                      style: TextStyle(
                        color: luma.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ok
                          ? [
                              t.aiTtsVoice(clip.voice ?? t.aiTtsDefaultVoice),
                              t.aiTtsClipMeta(
                                ttsMoney(clip.costUsd ?? 0),
                                ttsSeconds(clip.ms / 1000),
                              ),
                              if (clip.seconds case final s?)
                                t.aiTtsPlays(ttsSeconds(s)),
                            ].join(' · ')
                          : t.aiTtsClipFailed,
                      style: TextStyle(
                        color: ok ? luma.textMuted : luma.danger,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: luma.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  script.voice == 'female' ? t.aiTtsWoman : t.aiTtsMan,
                  style: TextStyle(
                    color: luma.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(error, style: TextStyle(color: luma.danger, fontSize: 12)),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => textOpen
                  ? _showText.remove(script.id)
                  : _showText.add(script.id)),
              icon: Icon(
                textOpen
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 18,
              ),
              label: Text(textOpen ? t.aiTtsHideText : t.aiTtsShowText),
            ),
          ),
          if (textOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: SelectableText(
                script.text,
                style: TextStyle(
                  color: luma.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
