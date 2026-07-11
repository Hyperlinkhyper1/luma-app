import 'package:flutter/material.dart';

import '../app/window_title_bar.dart';
import '../theme/luma_theme.dart';
import 'family_scope.dart';
import 'inbox_dialog.dart';

/// Top-right, app-wide inbox icon (shown in [WindowTitleBar]'s trailing
/// slot) with a badge for pending family invites. Tapping it opens
/// [showInboxDialog].
class InboxButton extends StatefulWidget {
  const InboxButton({super.key});

  @override
  State<InboxButton> createState() => _InboxButtonState();
}

class _InboxButtonState extends State<InboxButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final familyRepo = FamilyScope.of(context);
    final luma = context.luma;
    return ListenableBuilder(
      listenable: familyRepo,
      builder: (context, _) {
        final count = familyRepo.pendingInvites.length;
        return Tooltip(
          message: 'Inbox',
          waitDuration: const Duration(milliseconds: 500),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: GestureDetector(
              onTap: () => showInboxDialog(context, familyRepo: familyRepo),
              child: Container(
                width: 46,
                height: WindowTitleBar.height,
                color: _hovering ? luma.surfaceHover : Colors.transparent,
                alignment: Alignment.center,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.inbox_rounded, size: 18, color: luma.textSecondary),
                    if (count > 0)
                      Positioned(
                        top: -2,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints:
                              const BoxConstraints(minWidth: 15, minHeight: 15),
                          decoration: BoxDecoration(
                            color: luma.danger,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: luma.background, width: 1.5),
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
