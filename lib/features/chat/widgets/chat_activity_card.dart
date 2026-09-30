import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/luma_theme.dart';
import '../assistant_compose_mode.dart';
import 'chat_moon.dart';

/// Stands in for the thinking moon while a deep research or picture turn
/// runs: which sub-questions the agents took and who has reported back, or
/// a placeholder where the picture will appear.
class ChatActivityCard extends StatelessWidget {
  const ChatActivityCard({super.key, required this.activity});

  final AssistantActivity activity;

  /// The agent working now, when they take turns.
  int get _firstPending {
    for (var i = 0; i < activity.questions.length; i++) {
      if (!activity.done.contains(i)) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final t = L.of(context);
    final picture = activity.mode == AssistantComposeMode.picture;
    final total = activity.questions.length;
    final String title;
    if (picture) {
      title = t.assistantPictureDrawing;
    } else if (activity.writing) {
      title = t.assistantResearchWriting;
    } else if (total == 0) {
      title = t.assistantResearchPlanning;
    } else {
      title = t.assistantResearchProgress(activity.done.length, total);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ChatMoon(size: 24, animating: true),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: luma.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (picture)
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: luma.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: luma.border),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.image_outlined,
                size: 40,
                color: luma.textMuted.withValues(alpha: 0.6),
              ),
            )
          else if (total > 0)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: luma.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: luma.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.parallel
                        ? t.assistantResearchParallel
                        : t.assistantResearchSequential,
                    style: TextStyle(color: luma.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < total; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: activity.done.contains(i)
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    size: 17,
                                    color: luma.accent,
                                  )
                                : !activity.parallel && i != _firstPending
                                ? Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    size: 17,
                                    color: luma.textMuted,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: luma.textMuted,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              activity.questions[i],
                              style: TextStyle(
                                color: activity.done.contains(i)
                                    ? luma.textSecondary
                                    : luma.textPrimary,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
