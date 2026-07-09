import 'dart:convert';

import '../plugins/plugin_catalog_service.dart';
import '../plugins/plugin_repository.dart';
import '../plugins/installed/qr_code_generator/qr_code_repository.dart';
import 'providers/ai_client.dart';

/// The set of actions the assistant can perform on the user's behalf, e.g.
/// installing a plugin or generating a QR code, instead of just describing
/// how to do it manually.
///
/// Kept intentionally small (two tools). Add a third entry here directly
/// rather than building a generic "any plugin action" abstraction until
/// there's a second real example beyond QR.
class AiToolRegistry {
  AiToolRegistry({
    required PluginRepository pluginRepository,
    required QrCodeRepository qrCodeRepository,
  })  : _pluginRepository = pluginRepository,
        _qrCodeRepository = qrCodeRepository;

  final PluginRepository _pluginRepository;
  final QrCodeRepository _qrCodeRepository;

  static const _qrPluginId = 'qr-code-generator';

  /// Tool definitions in a provider-agnostic shape; each [AiClient]
  /// translates these into its own wire format.
  List<AiToolDefinition> get schemas => [
        const AiToolDefinition(
          name: 'install_plugin',
          description:
              'Downloads and installs a luma plugin by its id, so it shows '
              'up in the Plugins tab and nav rail. Use this when the user '
              "asks for something a plugin does but doesn't have it "
              'installed yet.',
          parameters: {
            'type': 'object',
            'properties': {
              'plugin_id': {
                'type': 'string',
                'description':
                    "The plugin's id, e.g. \"qr-code-generator\".",
              },
            },
            'required': ['plugin_id'],
          },
        ),
        const AiToolDefinition(
          name: 'generate_qr_code',
          description:
              'Generates a QR code for a URL and saves it to the QR Code '
              'Generator plugin\'s history. Installs that plugin '
              'automatically first if it isn\'t installed yet.',
          parameters: {
            'type': 'object',
            'properties': {
              'url': {
                'type': 'string',
                'description': 'The URL to encode as a QR code.',
              },
            },
            'required': ['url'],
          },
        ),
      ];

  /// Runs [name] with [input] and returns a small JSON-able result to send
  /// back to the model as the tool_result content.
  Future<Map<String, dynamic>> execute(
    String name,
    Map<String, dynamic> input,
  ) async {
    try {
      switch (name) {
        case 'install_plugin':
          final pluginId = input['plugin_id'] as String?;
          if (pluginId == null || pluginId.isEmpty) {
            return {'status': 'error', 'message': 'Missing plugin_id.'};
          }
          await _installPlugin(pluginId);
          return {'status': 'installed', 'plugin_id': pluginId};

        case 'generate_qr_code':
          final url = input['url'] as String?;
          if (url == null || url.isEmpty) {
            return {'status': 'error', 'message': 'Missing url.'};
          }
          await _installPlugin(_qrPluginId);
          await _qrCodeRepository.add(url);
          return {'status': 'generated', 'url': url};

        default:
          return {'status': 'error', 'message': 'Unknown tool "$name".'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Metadata extracted from a completed tool call, for the chat UI to
  /// render inline (e.g. a QR image). Returns null if [toolName]/[result]
  /// don't need any special rendering.
  static String? metadataFor(String toolName, Map<String, dynamic> result) {
    if (toolName == 'generate_qr_code' && result['status'] == 'generated') {
      return jsonEncode({'qrUrl': result['url']});
    }
    return null;
  }

  Future<void> _installPlugin(String pluginId) {
    return _pluginRepository.install(PluginCatalogEntry(
      id: pluginId,
      name: pluginId,
      description: '',
      icon: 'extension',
      category: 'Utility',
      version: '1.0.0',
    ));
  }
}
