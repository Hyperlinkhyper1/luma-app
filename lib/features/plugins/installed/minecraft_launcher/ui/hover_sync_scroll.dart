import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Wraps scrollable content so hover highlights (`ListTile`/`InkWell` hover
/// color, custom `MouseRegion` hover state, etc.) stay aligned with the row
/// under the cursor while scrolling with a mouse wheel.
///
/// Flutter's [MouseTracker] only re-evaluates which widget is under the
/// pointer when the pointer itself moves — scrolling the content underneath
/// a stationary cursor leaves the "lit up" hover highlight sitting on
/// whatever was under the cursor before the scroll, visibly detached from
/// the row that's actually there now. [MouseTracker.updateAllDevices] is the
/// documented way to force a re-check ("typically called during the post
/// frame phase, indicating a frame has passed and all objects have
/// potentially moved"), so this schedules one after every scroll frame.
class HoverSyncScroll extends StatelessWidget {
  const HoverSyncScroll({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          RendererBinding.instance.mouseTracker.updateAllDevices();
        });
        return false;
      },
      child: child,
    );
  }
}
