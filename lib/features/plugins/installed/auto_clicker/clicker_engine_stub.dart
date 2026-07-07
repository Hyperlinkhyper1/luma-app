/// Which mouse button a click should use.
enum ClickButton { left, middle, right }

/// A point in screen coordinates.
class ClickPoint {
  const ClickPoint(this.x, this.y);
  final int x;
  final int y;

  @override
  String toString() => '($x, $y)';
}

/// Web/stub: mouse simulation is unavailable.
class ClickerEngine {
  const ClickerEngine._();

  static bool get supported => false;

  static ClickPoint? get cursorPosition => null;

  static void click({
    required ClickButton button,
    required bool doubleClick,
    ClickPoint? at,
  }) {
    throw UnsupportedError(
      'Auto Clicker is only available in the desktop app.',
    );
  }
}
