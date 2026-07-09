import 'package:flutter/foundation.dart';

import '../../settings/settings_controller.dart';
import 'ai_agent_store.dart';
import 'ai_key_store.dart';
import 'ai_tools.dart';
import 'data/chat_repository.dart';
import 'providers/ai_client.dart';
import 'providers/ai_providers.dart';

/// Orchestrates one chat turn: persists the user's message, calls whichever
/// AI provider is selected in Settings (which internally loops through any
/// tool calls it requests), and persists the reply — all against the user's
/// own locally-stored API key for that provider.
class ChatController extends ChangeNotifier {
  ChatController({
    required ChatRepository repository,
    required AiKeyStore keyStore,
    required AiAgentStore agentStore,
    required AiToolRegistry tools,
    required SettingsController settings,
  })  : _repository = repository,
        _keyStore = keyStore,
        _agentStore = agentStore,
        _tools = tools,
        _settings = settings;

  final ChatRepository _repository;
  final AiKeyStore _keyStore;
  final AiAgentStore _agentStore;
  final AiToolRegistry _tools;
  final SettingsController _settings;

  static const _maxHistoryTurns = 20;

  static const _systemPrompt =
      'You are the AI assistant built into the luma app, a local file and '
      'productivity utility. Be concise and friendly. If the user asks for '
      'something a plugin does but they may not have it installed, use your '
      'tools to install it and complete the action for them rather than just '
      'explaining the steps.';

  bool _sending = false;
  bool get isSending => _sending;

  /// Sends [userText] in [conversationId]. Persists the user message
  /// immediately, then the assistant's reply (or an inline error message) —
  /// the UI should be watching `ChatRepository.watchMessages` and needs no
  /// return value from this call.
  Future<void> sendMessage(int conversationId, String userText) async {
    if (_sending) return;

    final providerId = _settings.aiProviderId;
    final apiKey = await _keyStore.readKey(providerId);
    if (apiKey == null) {
      final provider = aiProviderById(providerId);
      await _repository.addMessage(conversationId, 'error',
          'No ${provider.displayName} API key saved yet — add one in Settings.');
      return;
    }

    if (!_settings.canSendAiMessage) {
      await _repository.addMessage(
        conversationId,
        'error',
        "You've used all 10 assistant messages for today — more tomorrow.",
      );
      return;
    }

    _sending = true;
    notifyListeners();
    try {
      await _repository.addMessage(conversationId, 'user', userText);
      await _maybeTitleConversation(conversationId, userText);

      final history = await _repository.loadMessages(conversationId);
      final turns = _toTurns(history);
      final agentId = await _agentStore.activeAgentId(providerId);

      final result = await aiProviderById(providerId).client.chat(
            apiKey: apiKey,
            history: turns,
            systemPrompt: _systemPrompt,
            tools: _tools.schemas,
            executeTool: _tools.execute,
            metadataFor: AiToolRegistry.metadataFor,
            agentId: agentId,
          );

      await _repository.addMessage(
        conversationId,
        'assistant',
        result.text,
        metadataJson: result.metadataJson,
      );
      _settings.recordAiCall();
    } on AiError catch (e) {
      await _repository.addMessage(conversationId, 'error', e.message);
    } catch (e) {
      await _repository.addMessage(
          conversationId, 'error', 'Something went wrong: $e');
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> _maybeTitleConversation(
      int conversationId, String firstUserText) async {
    final existing = await _repository.loadMessages(conversationId);
    // Only the just-added user message present means this is conversation's
    // first turn — derive a short title from it.
    if (existing.length != 1) return;
    final trimmed = firstUserText.trim();
    final title =
        trimmed.length <= 40 ? trimmed : '${trimmed.substring(0, 40)}…';
    if (title.isNotEmpty) {
      await _repository.renameConversation(conversationId, title);
    }
  }

  List<AiTurn> _toTurns(List<ChatMessageRecord> history) {
    final turns = history.where((m) => m.role == 'user' || m.role == 'assistant');
    final tail = turns.length > _maxHistoryTurns
        ? turns.skip(turns.length - _maxHistoryTurns)
        : turns;
    return [for (final m in tail) AiTurn(role: m.role, text: m.content)];
  }
}
