/// File entitlements shared by the app and the authenticated AI proxies.
bool assistantFilesAllowed(String? planId) =>
    planId == 'orbit' || planId == 'nova';

const assistantFilePlanMessage =
    'File uploads and artifact generation require Orbit or Nova.';

int assistantChatBodyLimit(String? planId) =>
    assistantFilesAllowed(planId) ? 20 * 1024 * 1024 : 64 * 1024;

/// Older apps advertise the QR tool even during ordinary Free-plan chats.
/// Remove unavailable capabilities before forwarding those requests.
void stripAssistantFileTools(Map<String, dynamic> body) {
  final tools = body['tools'];
  if (tools is! List) return;
  final filtered = tools.where((tool) {
    if (tool is! Map) return true;
    final function = tool['function'];
    final name = function is Map ? function['name'] : tool['name'];
    return name != 'create_artifact' && name != 'generate_qr_code';
  }).toList();
  if (filtered.isEmpty) {
    body.remove('tools');
    if (const ['auto', 'none', 'required'].contains(body['tool_choice'])) {
      body.remove('tool_choice');
    }
  } else {
    body['tools'] = filtered;
  }
}

/// Recognizes native images, extracted uploads, and artifact tool requests.
bool assistantRequestUsesFiles(Map<String, dynamic> body) {
  bool containsFile(Object? value) {
    if (value is String) return value.contains('<luma_attachment');
    if (value is List) return value.any(containsFile);
    if (value is Map) {
      if (const [
        'image_url',
        'image',
        'file',
        'document',
        'input_image',
        'input_file'
      ].contains(value['type'])) return true;
      if (const ['create_artifact', 'generate_qr_code'].contains(value['name']))
        return true;
      return value.values.any(containsFile);
    }
    return false;
  }

  return containsFile(body['messages']) ||
      containsFile(body['tools']) ||
      containsFile(body['tool_choice']);
}

bool assistantRequestHasImages(Map<String, dynamic> body) {
  bool image(Object? value) {
    if (value is List) return value.any(image);
    if (value is Map) {
      if (const ['image_url', 'image', 'input_image'].contains(value['type']))
        return true;
      return value.values.any(image);
    }
    return false;
  }

  return image(body['messages']);
}
