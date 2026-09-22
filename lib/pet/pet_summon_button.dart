import 'package:flutter/material.dart';

import '../app/window_title_bar.dart';
import '../theme/luma_theme.dart';
import 'pet_scope.dart';

/// Title-bar button that summons the luma pet.
///
/// The hotkey is the fast way in, but it is invisible, it can be taken by
/// another app, and phones have no such thing at all — so the pet always has
/// a visible handle too. Matches [InboxButton]'s shape, since they sit side
/// by side.
class PetSummonButton extends StatefulWidget {
  const PetSummonButton({super.key});

  @override
  State<PetSummonButton> createState() => _PetSummonButtonState();
}

class _PetSummonButtonState extends State<PetSummonButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final pet = PetScope.of(context);
    // Only advertise the chord when it actually took: a shortcut the OS
    // refused is worse than no shortcut at all.
    final shortcut = pet.hotKeyRegistered
        ? '${pet.name} · ${pet.hotKeyLabel}'
        : pet.name;
    return Tooltip(
      message: shortcut,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Semantics(
          button: true,
          label: shortcut,
          child: GestureDetector(
            onTap: pet.open,
            child: Container(
              width: 46,
              height: WindowTitleBar.height,
              color: _hovering ? luma.surfaceHover : Colors.transparent,
              alignment: Alignment.center,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: _hovering ? luma.accent : luma.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
