import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../settings/settings_controller.dart';
import '../../../sync/sync_scope.dart';
import '../../../theme/luma_theme.dart';
import '../assistant_effort.dart';
import 'compact_menu.dart';

String assistantEffortLabel(L t, AssistantEffort effort) => switch (effort) {
  AssistantEffort.low => t.assistantEffortLow,
  AssistantEffort.medium => t.assistantEffortMedium,
  AssistantEffort.high => t.assistantEffortHigh,
  AssistantEffort.extra => t.assistantEffortExtra,
  AssistantEffort.max => t.assistantEffortMax,
};

/// "1.5", "3.5", "2" — the multiplier as the server publishes it.
String _multiplier(double weight) => weight == weight.roundToDouble()
    ? weight.toStringAsFixed(0)
    : weight.toStringAsFixed(1);

/// The composer's effort pill: names the level (or Ultra Reasoning) and
/// opens a menu of levels with what each costs, plus the Ultra Reasoning
/// switch. Only shown for Luma AI, the one provider effort applies to.
class AssistantEffortButton extends StatefulWidget {
  const AssistantEffortButton({super.key, required this.settings});

  final SettingsController settings;

  @override
  State<AssistantEffortButton> createState() => _AssistantEffortButtonState();
}

/// The menu row that flips Ultra Reasoning rather than picking a level.
const _ultraToggle = 'ultra';

class _AssistantEffortButtonState extends State<AssistantEffortButton> {
  SettingsController get settings => widget.settings;

  bool get _ultraOn => ultraReasoningActive(
    enabled: settings.ultraReasoning,
    planId: settings.selectedPlanId,
    providerId: settings.aiProviderId,
  );

  Future<Map<String, double>> _weights() async {
    final sync = SyncScope.maybeOf(context);
    if (sync == null || !sync.serverReady) return const {};
    try {
      return (await sync.aiStatus())?.effortWeights ?? const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _open() async {
    final weights = await _weights();
    if (!mounted) return;
    final luma = context.luma;
    final t = L.of(context);
    final button = context.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final current = AssistantEffort.parse(settings.assistantEffort);
    final ultraAllowed = ultraReasoningUnlocked(settings.selectedPlanId);
    final ultraOn = _ultraOn;

    PopupMenuEntry<String> level(AssistantEffort effort) {
      final selected = !ultraOn && effort == current;
      final weight = weights[effort.name] ?? effort.fallbackWeight;
      final warn = effort == AssistantEffort.max;
      return CompactMenuItem<String>(
        value: effort.name,
        child: Row(
          children: [
            Text(
              assistantEffortLabel(t, effort),
              style: TextStyle(
                color: selected ? luma.accent : luma.textPrimary,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: 7),
            if (effort == AssistantEffort.recommended)
              _Tag(text: t.assistantEffortRecommended, color: luma.textMuted)
            else if (weight > 1)
              _Tag(
                text: t.assistantEffortUsage(_multiplier(weight)),
                color: warn ? luma.warning : luma.textMuted,
                icon: warn ? Icons.warning_amber_rounded : null,
              ),
            const Spacer(),
            SizedBox(
              width: 15,
              child: selected
                  ? Icon(Icons.check_rounded, size: 15, color: luma.accent)
                  : null,
            ),
          ],
        ),
      );
    }

    final picked = await showMenu<String>(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 270),
      menuPadding: kCompactMenuPadding,
      color: luma.surface,
      shape: compactMenuShape(luma),
      items: [
        CompactMenuLabel<String>(
          padding: const EdgeInsets.fromLTRB(
            kCompactMenuTextPadding,
            4,
            kCompactMenuTextPadding,
            5,
          ),
          child: Text(
            t.assistantEffortDescription,
            style: TextStyle(color: luma.textMuted, fontSize: 11, height: 1.3),
          ),
        ),
        for (final effort in AssistantEffort.values) level(effort),
        const PopupMenuDivider(height: 9),
        CompactMenuItem<String>(
          value: _ultraToggle,
          enabled: ultraAllowed,
          rowHeight: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.assistantUltraReasoning,
                        style: TextStyle(
                          color: ultraAllowed
                              ? (ultraOn ? luma.accent : luma.textPrimary)
                              : luma.textMuted,
                          fontSize: 12.5,
                          fontWeight: ultraOn
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ultraAllowed
                            ? t.assistantUltraReasoningDescription
                            : t.assistantUltraReasoningPlan,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textMuted,
                          fontSize: 10.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IgnorePointer(
                  child: SizedBox(
                    height: 20,
                    child: FittedBox(
                      child: Switch(
                        value: ultraOn,
                        onChanged: ultraAllowed ? (_) {} : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    if (picked == null) return;
    if (picked == _ultraToggle) {
      settings.setUltraReasoning(!settings.ultraReasoning);
    } else {
      settings.setAssistantEffort(picked);
      settings.setUltraReasoning(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        if (!effortSupported(settings.aiProviderId)) {
          return const SizedBox.shrink();
        }
        final ultra = _ultraOn;
        final effort = AssistantEffort.parse(settings.assistantEffort);
        return Tooltip(
          message: t.assistantEffortTitle,
          child: TextButton.icon(
            onPressed: _open,
            style: TextButton.styleFrom(
              foregroundColor: ultra ? luma.accent : luma.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(
              ultra ? Icons.all_inclusive_rounded : Icons.speed_rounded,
              size: 15,
            ),
            label: Text(
              ultra ? t.assistantUltraReasoning : assistantEffortLabel(t, effort),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: luma.border),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 10.5, color: color),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
