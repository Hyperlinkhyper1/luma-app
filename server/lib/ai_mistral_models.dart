const documentedMistralChatModels = <String, String>{
  'zai-glm-5-3': 'Z.ai GLM 5.3',
  'zai-glm-5-2': 'Z.ai GLM 5.2 (deprecated; use GLM 5.3)',
};

List<String> mistralModelSuggestions(Iterable<String> discovered) {
  return {...discovered, ...documentedMistralChatModels.keys}.toList()..sort();
}
