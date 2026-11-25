import 'dart:convert';

import 'assistant_compose_mode.dart';
import 'providers/ai_client.dart';

/// Ultra Reasoning: deep research writes a first draft, then a reviewer
/// checks it (with web search when it has it) and a reviser fixes what the
/// reviewer found, round after round until the reviewer passes it or
/// [rounds] run out. Every call goes through [client] like a normal turn at
/// the highest effort, so the server meters each one.
class UltraReasoning {
  UltraReasoning({
    required this.client,
    required this.apiKey,
    required this.parallel,
    required this.systemPrompt,
    this.tools = const [],
    this.executeTool,
    this.agentCount = 4,
    this.rounds = 3,
    this.onActivity,
    this.onText,
  });

  final AiClient client;
  final String apiKey;
  final bool parallel;
  final String systemPrompt;

  /// Read-only tools (web search) for the research agents and the reviewer.
  final List<AiToolDefinition> tools;
  final AiToolExecutor? executeTool;
  final int agentCount;
  final int rounds;
  final void Function(AssistantActivity activity)? onActivity;
  final AiTextProgress? onText;

  static const _reviewPrompt =
      'You are a strict reviewer. Check the draft answer below against the '
      'user\'s question: factual errors, wrong numbers or code, missing parts '
      'of the question, weak reasoning, unclear or badly structured passages. '
      'Use your tools to verify facts when they help. Reply with only JSON: '
      '{"verdict": "pass" or "revise", "issues": ["specific issue and how to '
      'fix it", ...]}. Say "pass" only when nothing important would improve.';

  static const _revisePrompt =
      'Rewrite the draft answer below so it fixes every issue the reviewer '
      'raised, keeping what was already right. Reply with only the improved '
      'answer for the user; do not mention the draft, the reviewer or this '
      'process.';

  Future<UltraReasoningResult> run(List<AiTurn> history) async {
    final question = history.last.text;
    final images = history.last.images;
    final earlier = history.take(history.length - 1).toList();
    AiTokenUsage? usage;

    final research = await DeepResearch(
      client: client,
      apiKey: apiKey,
      parallel: parallel,
      systemPrompt: systemPrompt,
      agentTools: tools,
      executeTool: executeTool,
      agentCount: agentCount,
      onActivity: onActivity,
      onText: onText,
    ).run(history);
    usage = addAiUsage(usage, research.usage);
    var draft = research.text;
    var checks = 0;
    var revisions = 0;

    Future<Map<String, dynamic>> noTool(
      String name,
      Map<String, dynamic> input,
    ) async => {'status': 'unavailable'};
    String? noMetadata(String name, Map<String, dynamic> result) => null;

    for (var round = 1; round <= rounds; round++) {
      onActivity?.call(AssistantActivity.review(round: round, rounds: rounds));
      final review = await client.chat(
        apiKey: apiKey,
        history: [
          AiTurn(
            role: 'user',
            images: images,
            text:
                'The user asked: $question\n\n<draft_answer>\n$draft\n'
                '</draft_answer>',
          ),
        ],
        systemPrompt: '$systemPrompt\n\n$_reviewPrompt',
        tools: tools,
        executeTool: executeTool ?? noTool,
        metadataFor: noMetadata,
      );
      usage = addAiUsage(usage, review.usage);
      checks = round;
      final verdict = parseUltraReview(review.text);
      if (verdict.pass) break;

      onActivity?.call(
        AssistantActivity.review(round: round, rounds: rounds, improving: true),
      );
      final revised = await client.chat(
        apiKey: apiKey,
        history: [
          ...earlier,
          AiTurn(
            role: 'user',
            images: images,
            text:
                '$question\n\n<draft_answer>\n$draft\n</draft_answer>\n\n'
                '<review>\n${verdict.issues.map((i) => '- $i').join('\n')}\n'
                '</review>',
          ),
        ],
        systemPrompt: '$systemPrompt\n\n$_revisePrompt',
        tools: const [],
        executeTool: noTool,
        metadataFor: noMetadata,
        onText: onText,
      );
      usage = addAiUsage(usage, revised.usage);
      if (revised.text.trim().isNotEmpty) {
        draft = revised.text;
        revisions++;
      }
    }
    return UltraReasoningResult(
      AiChatResult(text: draft, usage: usage),
      checks: checks,
      revisions: revisions,
    );
  }
}

class UltraReasoningResult {
  const UltraReasoningResult(
    this.result, {
    required this.checks,
    required this.revisions,
  });

  final AiChatResult result;

  /// Review rounds run, and how many of them led to a rewrite.
  final int checks;
  final int revisions;
}

/// Reads a reviewer's reply: the JSON it was asked for when it managed it,
/// otherwise a bare "pass", or any bulleted lines as issues. A reply with
/// nothing usable counts as a pass so a confused reviewer can't loop.
({bool pass, List<String> issues}) parseUltraReview(String text) {
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end > start) {
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map) {
        final issues = [
          if (decoded['issues'] case final List list)
            for (final item in list)
              if (item is String && item.trim().isNotEmpty) item.trim(),
        ];
        final pass =
            '${decoded['verdict']}'.toLowerCase().trim() == 'pass' ||
            issues.isEmpty;
        return (pass: pass, issues: pass ? const [] : issues);
      }
    } catch (_) {}
  }
  final issues = [
    for (final line in const LineSplitter().convert(text))
      if (RegExp(r'^\s*(?:\d+[.)]|[-*•])\s+(.+)$').firstMatch(line)
          case final match?)
        match.group(1)!.trim(),
  ];
  return (pass: issues.isEmpty, issues: issues);
}
