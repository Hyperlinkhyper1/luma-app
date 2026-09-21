import 'package:desktop_multi_window/desktop_multi_window.dart';

/// One main-engine endpoint used by the pet window for navigation, persisted
/// pet state, and Auto Clicker commands.
const petMainChannel = WindowMethodChannel(
  'luma/pet/main',
  mode: ChannelMode.unidirectional,
);

const String petWindowKind = 'luma-pet';

const String petMethodSnapshot = 'snapshot';
const String petMethodPat = 'pat';
const String petMethodRecordOpen = 'recordOpen';
const String petMethodOpenTarget = 'openTarget';
const String petMethodDismiss = 'dismiss';
const String petMethodAutoClicker = 'autoClicker';

const String petWindowMethodClose = 'window_close';
