import 'dart:convert';

import '../../account/plan.dart';
import '../../l10n/current_l.dart';
import 'providers/ai_client.dart';
import 'providers/ai_modes.dart';
import 'providers/ai_providers.dart';

/// What the next message in the Assistant does, picked from the composer's
/// + menu. Nova only; everyone else always sends a plain [chat] turn.
enum AssistantComposeMode { chat, plan, deepResearch, picture }

/// The plan the + menu is unlocked from.
const kComposeModesMinPlan = 'nova';

bool composeModesUnlocked(String? planId) =>
    planAtLeast(planId, kComposeModesMinPlan);

/// Deep research runs on Nebula and Pulsar, whose agents work in parallel,
/// and on the on-device Luma Assistant, whose agents take turns because
/// there is only one local model to go around.
bool deepResearchAvailable(String providerId, String aiMode) {
  if (providerId == AiProviderId.local.name) return true;
  return providerId == AiProviderId.google.name &&
      (aiMode == AiMode.smarter.name || aiMode == AiMode.smartest.name);
}

bool deepResearchRunsInParallel(String providerId) =>
    providerId != AiProviderId.local.name;

/// Added to the system prompt for a plan mode turn.
const kPlanModePrompt =
    'PLAN MODE is on. Do not carry out the request and do not claim anything '
    'was done. Instead, think it through and reply with a clear plan: a '
    'one-line goal, then numbered steps, each saying what will happen and '
    'why, then any open questions or choices the user should make. Keep it '
    'concrete and short. End by asking whether to go ahead or change '
    'anything.';

/// What the Assistant is busy with while a mode's reply is on its way, for
/// the transcript to show instead of the plain thinking moon.
class AssistantActivity {
  const AssistantActivity.research({
    required this.questions,
    required this.done,
    required this.parallel,
    this.writing = false,
  }) : mode = AssistantComposeMode.deepResearch;

  const AssistantActivity.picture()
    : mode = AssistantComposeMode.picture,
      questions = const [],
      done = const {},
      parallel = false,
      writing = false;

  final AssistantComposeMode mode;

  /// The sub-questions the research agents took on; empty while planning.
  final List<String> questions;

  /// Indexes into [questions] whose agent has reported back.
  final Set<int> done;
  final bool parallel;

  /// Every agent is back and the final answer is being written.
  final bool writing;
}

/// Deep research: a lead call splits the question into focused
/// sub-questions, one agent answers each (all at once, or one after another
/// when [parallel] is false), and a final call writes the answer from their
/// findings. Every call goes through [client] like a normal turn, so it is
/// metered as ordinary tokens.
class DeepResearch {
  DeepResearch({
    required this.client,
    required this.apiKey,
    required this.parallel,
    required this.systemPrompt,
    this.agentTools = const [],
    this.executeTool,
    this.agentCount = 3,
    this.onActivity,
    this.onText,
  });

  final AiClient client;
  final String apiKey;
  final bool parallel;
  final String systemPrompt;

  /// Tools the agents may use — read-only ones only, since several run at
  /// once and none should act on the user's behalf.
  final List<AiToolDefinition> agentTools;
  final AiToolExecutor? executeTool;
  final int agentCount;
  final void Function(AssistantActivity activity)? onActivity;
  final AiTextProgress? onText;

  static const _leadPrompt =
      'You lead a small research team. Split the user\'s latest question '
      'into focused sub-questions that together cover it thoroughly, each '
      'answerable on its own. Reply with only a JSON array of strings, no '
      'other text.';

  static const _agentPrompt =
      'You are one agent on a research team. Answer only your assigned '
      'sub-question, as thoroughly and accurately as you can: key facts, '
      'numbers, trade-offs and caveats. Say plainly when you are unsure. '
      'Use your tools when they help. Write compact notes for the lead, not '
      'a polished answer.';

  static const _writePrompt =
      'Several research agents investigated the user\'s question. Their '
      'notes are below. Write the final answer for the user: well '
      'structured, thorough, reconciling any disagreements between agents, '
      'and honest about what stays uncertain. Do not mention the agents or '
      'the research process.';

  Future<AiChatResult> run(List<AiTurn> history) async {
    final question = history.last.text;
    AiTokenUsage? usage;

    Future<Map<String, dynamic>> noTool(
      String name,
      Map<String, dynamic> input,
    ) async => {'status': 'unavailable'};
    String? noMetadata(String name, Map<String, dynamic> result) => null;

    onActivity?.call(
      AssistantActivity.research(
        questions: const [],
        done: const {},
        parallel: parallel,
      ),
    );
    final lead = await client.chat(
      apiKey: apiKey,
      history: [
        ...history.take(history.length - 1),
        AiTurn(
          role: 'user',
          images: history.last.images,
          text:
              '$question\n\n(List at most $agentCount sub-questions as a '
              'JSON array.)',
        ),
      ],
      systemPrompt: '$systemPrompt\n\n$_leadPrompt',
      tools: const [],
      executeTool: noTool,
      metadataFor: noMetadata,
    );
    usage = addAiUsage(usage, lead.usage);
    final questions = parseResearchQuestions(
      lead.text,
      max: agentCount,
      fallback: question,
    );

    final done = <int>{};
    final findings = List<String?>.filled(questions.length, null);
    void report({bool writing = false}) => onActivity?.call(
      AssistantActivity.research(
        questions: questions,
        done: Set.of(done),
        parallel: parallel,
        writing: writing,
      ),
    );
    report();

    AiError? firstError;
    Future<void> runAgent(int i) async {
      try {
        final result = await client.chat(
          apiKey: apiKey,
          history: [
            AiTurn(
              role: 'user',
              images: history.last.images,
              text:
                  'The user asked: $question\n\nYour sub-question: '
                  '${questions[i]}',
            ),
          ],
          systemPrompt: '$systemPrompt\n\n$_agentPrompt',
          tools: agentTools,
          executeTool: executeTool ?? noTool,
          metadataFor: noMetadata,
        );
        usage = addAiUsage(usage, result.usage);
        findings[i] = result.text.trim();
      } on AiError catch (e) {
        firstError ??= e;
      }
      done.add(i);
      report();
    }

    if (parallel) {
      await Future.wait([
        for (var i = 0; i < questions.length; i++) runAgent(i),
      ]);
    } else {
      for (var i = 0; i < questions.length; i++) {
        await runAgent(i);
      }
    }
    if (findings.every((f) => f == null || f.isEmpty)) {
      throw firstError ?? AiApiError(currentL.assistantResearchAgentsEmpty);
    }

    report(writing: true);
    final notes = StringBuffer();
    for (var i = 0; i < questions.length; i++) {
      final finding = findings[i];
      if (finding == null || finding.isEmpty) continue;
      notes.writeln('## ${questions[i]}\n$finding\n');
    }
    final answer = await client.chat(
      apiKey: apiKey,
      history: [
        ...history.take(history.length - 1),
        AiTurn(
          role: 'user',
          images: history.last.images,
          text: '$question\n\n<research_notes>\n$notes</research_notes>',
        ),
      ],
      systemPrompt: '$systemPrompt\n\n$_writePrompt',
      tools: const [],
      executeTool: noTool,
      metadataFor: noMetadata,
      onText: onText,
    );
    usage = addAiUsage(usage, answer.usage);
    return AiChatResult(text: answer.text, usage: usage);
  }
}

/// Reads the lead's sub-questions: a JSON array when the model managed one,
/// otherwise one per numbered or bulleted line. Falls back to [fallback]
/// alone so research still runs when the lead rambles.
List<String> parseResearchQuestions(
  String text, {
  required int max,
  required String fallback,
}) {
  final found = <String>[];
  final start = text.indexOf('[');
  final end = text.lastIndexOf(']');
  if (start != -1 && end > start) {
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is List) {
        for (final item in decoded) {
          if (item is String && item.trim().isNotEmpty) found.add(item.trim());
        }
      }
    } catch (_) {}
  }
  if (found.isEmpty) {
    final item = RegExp(r'^\s*(?:\d+[.)]|[-*•])\s+(.+)$');
    for (final line in const LineSplitter().convert(text)) {
      final match = item.firstMatch(line);
      if (match != null) found.add(match.group(1)!.trim());
    }
  }
  final unique = <String>[];
  for (final q in found) {
    if (!unique.contains(q)) unique.add(q);
  }
  if (unique.isEmpty) return [fallback];
  return unique.take(max).toList();
}
