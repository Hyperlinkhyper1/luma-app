import 'package:test/test.dart';

import '../lib/ai_mistral_models.dart';

void main() {
  test('GLM models remain searchable when Mistral discovery omits them', () {
    final ids = mistralModelSuggestions(['mistral-small-latest']);
    expect(ids, containsAll(['zai-glm-5-2', 'zai-glm-5-3']));
    expect(ids, contains('mistral-small-latest'));
    expect(documentedMistralChatModels['zai-glm-5-2'], contains('deprecated'));
  });

  test(
      'documented suggestions survive unavailable discovery without duplicates',
      () {
    expect(mistralModelSuggestions([]), ['zai-glm-5-2', 'zai-glm-5-3']);
    expect(mistralModelSuggestions(['zai-glm-5-3', 'zai-glm-5-3']),
        ['zai-glm-5-2', 'zai-glm-5-3']);
  });
}
