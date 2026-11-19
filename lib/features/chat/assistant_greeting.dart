import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

enum GreetingPeriod { night, morning, afternoon, evening }

GreetingPeriod greetingPeriodFor(DateTime time) {
  final hour = time.hour;
  if (hour < 5) return GreetingPeriod.night;
  if (hour < 12) return GreetingPeriod.morning;
  if (hour < 18) return GreetingPeriod.afternoon;
  return GreetingPeriod.evening;
}

/// Every line the assistant may greet with during [period], with or without
/// the user's [name].
List<String> assistantGreetings(L t, GreetingPeriod period, String? name) {
  final named = name != null;
  switch (period) {
    case GreetingPeriod.night:
      return named
          ? [
              t.assistantGreetingNight1Name(name),
              t.assistantGreetingNight2Name(name),
              t.assistantGreetingNight3Name(name),
            ]
          : [
              t.assistantGreetingNight1,
              t.assistantGreetingNight2,
              t.assistantGreetingNight3,
            ];
    case GreetingPeriod.morning:
      return named
          ? [
              t.assistantGreetingMorningName(name),
              t.assistantGreetingMorning1Name(name),
              t.assistantGreetingMorning2Name(name),
              t.assistantGreetingMorning3Name(name),
            ]
          : [
              t.assistantGreetingMorning,
              t.assistantGreetingMorning1,
              t.assistantGreetingMorning2,
              t.assistantGreetingMorning3,
            ];
    case GreetingPeriod.afternoon:
      return named
          ? [
              t.assistantGreetingAfternoonName(name),
              t.assistantGreetingAfternoon1Name(name),
              t.assistantGreetingAfternoon2Name(name),
              t.assistantGreetingAfternoon3Name(name),
            ]
          : [
              t.assistantGreetingAfternoon,
              t.assistantGreetingAfternoon1,
              t.assistantGreetingAfternoon2,
              t.assistantGreetingAfternoon3,
            ];
    case GreetingPeriod.evening:
      return named
          ? [
              t.assistantGreetingEveningName(name),
              t.assistantGreetingEvening1Name(name),
              t.assistantGreetingEvening2Name(name),
              t.assistantGreetingEvening3Name(name),
            ]
          : [
              t.assistantGreetingEvening,
              t.assistantGreetingEvening1,
              t.assistantGreetingEvening2,
              t.assistantGreetingEvening3,
            ];
  }
}

/// The new-chat greeting. The assistant page stays alive in the shell's
/// IndexedStack for the whole session, so the greeting watches the clock
/// itself instead of only reading it when the page happens to rebuild, and
/// picks a fresh line each time the time of day changes.
class AssistantGreeting extends StatefulWidget {
  const AssistantGreeting({
    super.key,
    required this.name,
    this.style,
    this.textAlign,
    this.clock = DateTime.now,
    this.random,
  });

  final String? name;
  final TextStyle? style;
  final TextAlign? textAlign;
  final DateTime Function() clock;
  final math.Random? random;

  @override
  State<AssistantGreeting> createState() => _AssistantGreetingState();
}

class _AssistantGreetingState extends State<AssistantGreeting> {
  late final math.Random _random = widget.random ?? math.Random();
  late GreetingPeriod _period;
  late int _pick;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _period = greetingPeriodFor(widget.clock());
    _pick = _random.nextInt(1 << 16);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkClock());
  }

  void _checkClock() {
    final period = greetingPeriodFor(widget.clock());
    if (period == _period || !mounted) return;
    setState(() {
      _period = period;
      _pick = _random.nextInt(1 << 16);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = assistantGreetings(L.of(context), _period, widget.name);
    return Text(
      lines[_pick % lines.length],
      textAlign: widget.textAlign,
      style: widget.style,
    );
  }
}
