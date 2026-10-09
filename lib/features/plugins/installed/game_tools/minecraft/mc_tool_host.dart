import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';
import 'mc_tool_catalog.dart';
import 'ui/mc_style.dart';

/// What the hub hands a tool: its own name and look, and the way back.
///
/// Tools frame themselves through [frame] so every one of them gets the same
/// back link, heading and backdrop without repeating the catalogue entry.
class McToolHost {
  const McToolHost({required this.tool, required this.onBack});

  final McTool tool;
  final VoidCallback onBack;

  Widget frame(
    BuildContext context, {
    required Widget child,
    List<Widget> actions = const [],
    bool scroll = true,
  }) {
    final t = L.of(context);
    return McToolFrame(
      title: tool.title(t),
      subtitle: tool.blurb(t),
      section: tool.group.audience.label(t),
      icon: tool.icon,
      hue: tool.hue,
      onBack: onBack,
      actions: actions,
      scroll: scroll,
      child: child,
    );
  }
}
