import 'dart:convert';

import 'package:luma_sync_server/ai_mode_routing.dart';
import 'package:luma_sync_server/api.dart';
import 'package:test/test.dart';

void main() {
  test('a queued streaming run survives restart with its request', () {
    final job = BenchmarkGenJob(
      id: 'queued',
      kind: 'pagoda',
      sceneId: 'pagoda_demo',
      name: 'Demo',
      vendor: '',
      route: const AiModeRoute(AiUpstream.openrouter, 'demo/model'),
      prompt: 'Build the scene.',
      maxTokens: 64000,
      startedAtMs: 100,
    );
    final restored = BenchmarkGenJob.fromState(
        jsonDecode(jsonEncode(job.toState())) as Map<String, dynamic>);
    expect(restored, isNotNull);
    expect(restored!.status, 'running');
    expect(restored.phase, 'queued');
    expect(restored.prompt, job.prompt);
    expect(restored.route.model, job.route.model);
  });

  test('a batch retry survives restart with its prompt and retry count', () {
    final job = BenchmarkGenJob(
      id: 'job',
      kind: 'pagoda',
      sceneId: 'pagoda_demo',
      name: 'Demo',
      vendor: '',
      route: const AiModeRoute(AiUpstream.openrouter, 'demo/model:batch'),
      prompt: 'Build the complete scene.',
      maxTokens: 64000,
      startedAtMs: 100,
      batchStartedAtMs: 200,
      batchId: 'batch2',
      autoCompact: true,
      compactAttempt: 1,
    );
    final restored = BenchmarkGenJob.fromState(
        jsonDecode(jsonEncode(job.toState())) as Map<String, dynamic>);
    expect(restored, isNotNull);
    expect(restored!.autoCompact, isTrue);
    expect(restored.prompt, 'Build the complete scene.');
    expect(restored.compactAttempt, 1);
    expect(restored.batchId, 'batch2');
    expect(restored.batchStartedAtMs, 200);
  });

  test('a retry waiting to submit a new batch survives restart', () {
    final job = BenchmarkGenJob(
      id: 'job',
      kind: 'pagoda',
      sceneId: 'pagoda_demo',
      name: 'Demo',
      vendor: '',
      route: const AiModeRoute(AiUpstream.openrouter, 'demo/model:batch'),
      prompt: 'Build the complete scene.',
      maxTokens: 64000,
      startedAtMs: 100,
      autoCompact: true,
      compactAttempt: 1,
    );
    final restored = BenchmarkGenJob.fromState(
        jsonDecode(jsonEncode(job.toState())) as Map<String, dynamic>);
    expect(restored, isNotNull);
    expect(restored!.batchId, isNull);
    expect(restored.autoCompact, isTrue);
    expect(restored.compactAttempt, 1);
    expect(restored.prompt, job.prompt);
  });
}
