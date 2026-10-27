import 'package:luma_sync_server/api.dart';
import 'package:test/test.dart';

/// The AI proxies bill the operator's key, so only a fixed set of client
/// fields may reach the upstream provider.
void main() {
  test('only allow-listed fields survive', () {
    final out = Api.allowedAiFields({
      'messages': [
        {'role': 'user', 'content': 'hi'}
      ],
      'tools': [],
      'tool_choice': 'auto',
      'temperature': 0.4,
      'top_p': 0.9,
      'model': 'mistral-large-latest',
      'models': ['openai/o1-pro', 'anthropic/claude-opus'],
      'plugins': [
        {'id': 'web'}
      ],
      'provider': {'order': ['expensive']},
      'max_completion_tokens': 100000,
      'stream': true,
      'n': 8,
      'agent_id': 'ag_123',
    });
    expect(out.keys.toSet(),
        {'messages', 'tools', 'tool_choice', 'temperature', 'top_p'});
  });

  test('absent fields stay absent', () {
    expect(Api.allowedAiFields({'messages': []}).keys, ['messages']);
  });

  test('Luma Support runs on one server-chosen model', () {
    expect(Api.kSupportMistralModel, 'mistral-small-latest');
  });
}
