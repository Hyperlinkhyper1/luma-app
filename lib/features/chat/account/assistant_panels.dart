import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import 'assistant_agents_view.dart';
import 'assistant_settings_view.dart';
import 'assistant_usage_view.dart';

/// The screens behind the account menu at the foot of the chat sidebar.
enum AssistantPanel { usage, settings, agents }

/// Opens the Claude-style account menu just above the sidebar footer —
/// [footerRect] is the footer's global rect — and then the picked panel.
Future<void> showAssistantAccountMenu(
  BuildContext context, {
  required Rect footerRect,
  required String? email,
  required ValueChanged<String> onOpenPlugin,
}) async {
  final luma = context.luma;
  final t = L.of(context);
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final topLeft = overlay.globalToLocal(footerRect.topLeft);
  // showMenu always puts the menu's top at `position.top`, so to open it
  // upward from the footer the top is lifted by the menu's own height: the
  // optional email line, three 40px rows and the menu's 8px padding.
  final menuHeight = (email == null ? 0 : 32) + 3 * 40 + 16;
  final position = RelativeRect.fromLTRB(
    topLeft.dx + 8,
    topLeft.dy - menuHeight - 4,
    overlay.size.width - topLeft.dx - footerRect.width + 8,
    overlay.size.height - topLeft.dy + 4,
  );

  PopupMenuItem<AssistantPanel> item(
    AssistantPanel value,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: value,
    height: 40,
    child: Row(
      children: [
        Icon(icon, size: 18, color: luma.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: luma.textPrimary, fontSize: 13.5)),
      ],
    ),
  );

  final picked = await showMenu<AssistantPanel>(
    context: context,
    position: position,
    color: luma.surface,
    constraints: BoxConstraints(
      minWidth: (footerRect.width - 16).clamp(200, 320),
      maxWidth: 320,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: luma.border),
    ),
    items: [
      if (email != null)
        PopupMenuItem<AssistantPanel>(
          enabled: false,
          height: 32,
          child: Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: luma.textMuted, fontSize: 12),
          ),
        ),
      item(
        AssistantPanel.usage,
        Icons.data_usage_rounded,
        t.assistantMenuUsage,
      ),
      item(
        AssistantPanel.settings,
        Icons.settings_outlined,
        t.assistantMenuSettings,
      ),
      item(
        AssistantPanel.agents,
        Icons.smart_toy_outlined,
        t.assistantMenuAgents,
      ),
    ],
  );
  if (picked == null || !context.mounted) return;
  await showAssistantPanel(context, picked, onOpenPlugin: onOpenPlugin);
}

/// Shows [panel] as a large sheet over the assistant — full screen on a
/// phone — with a close button in the corner, like the Claude app's
/// settings.
Future<void> showAssistantPanel(
  BuildContext context,
  AssistantPanel panel, {
  required ValueChanged<String> onOpenPlugin,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      final compact = size.width < 720;
      final luma = dialogContext.luma;
      final Widget body = switch (panel) {
        AssistantPanel.usage => AssistantUsageView(
          onOpenPlugin: (id) {
            Navigator.of(dialogContext).pop();
            onOpenPlugin(id);
          },
        ),
        AssistantPanel.settings => const AssistantSettingsView(),
        AssistantPanel.agents => AssistantAgentsView(
          onOpenPlugin: (id) {
            Navigator.of(dialogContext).pop();
            onOpenPlugin(id);
          },
        ),
      };
      final content = Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              tooltip: MaterialLocalizations.of(dialogContext).closeButtonLabel,
              onPressed: () => Navigator.of(dialogContext).pop(),
              color: luma.textSecondary,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ),
        ],
      );
      if (compact) {
        return Dialog.fullscreen(
          backgroundColor: luma.background,
          child: SafeArea(child: content),
        );
      }
      return Dialog(
        backgroundColor: luma.background,
        insetPadding: const EdgeInsets.all(32),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: luma.border),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 1000,
            maxHeight: 760,
            minHeight: size.height < 600 ? 0 : 560,
          ),
          child: SizedBox(width: 1000, child: content),
        ),
      );
    },
  );
}

/// The heading every panel opens with, sized like the Claude app's.
class AssistantPanelTitle extends StatelessWidget {
  const AssistantPanelTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: luma.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// "1.2 KB" / "3.4 MB" for the storage rows.
String formatStorageBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value < 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(0)} '
      '${units[unit]}';
}
