import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/widgets.dart';
import '../../../../theme/luma_theme.dart';
import 'calc_expression.dart';
import 'calculator_store.dart';
import 'graph_panel.dart';
import 'unit_converter_drawer.dart';

/// Below this the graph and the keypad stop fitting side by side and advanced
/// mode splits them into two tabs instead.
const _wideLayout = 900.0;

/// The Calculator plugin. Basic mode is an everyday calculator; Advanced turns
/// it into a graphing calculator — scientific keys plus a pannable plot of any
/// number of functions of x. The ☰ button in its header opens a unit converter
/// (km to miles, °C to °F, kg to pounds, …).
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final _store = CalculatorStore();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _advanced = false;
  bool _showGraphTab = false;
  bool _second = false;

  String _input = '';
  String? _answer;
  String? _error;

  /// Set the moment `=` lands: the next digit starts a new sum, while the next
  /// operator carries on from the answer.
  bool _answerIsFresh = false;

  @override
  void dispose() {
    _store.flush();
    super.dispose();
  }

  // ---- Entry line ----------------------------------------------------------

  void _insert(String text, {required bool startsNewEntry}) {
    setState(() {
      if (_answerIsFresh) {
        _input = startsNewEntry ? '' : (_answer ?? '');
        _answerIsFresh = false;
        _answer = null;
      }
      _input += text;
      _error = null;
      _second = false;
    });
  }

  void _clear() => setState(() {
        _input = '';
        _answer = null;
        _error = null;
        _answerIsFresh = false;
      });

  void _backspace() => setState(() {
        if (_answerIsFresh) {
          _input = _answer ?? '';
          _answer = null;
          _answerIsFresh = false;
        }
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
        _error = null;
      });

  /// One key for both brackets: it closes an open one when that's what the
  /// entry needs, and opens a new one otherwise.
  void _smartBracket() {
    final open = '('.allMatches(_input).length;
    final closed = ')'.allMatches(_input).length;
    final last = _input.isEmpty ? '' : _input.substring(_input.length - 1);
    final closes = open > closed && RegExp(r'[0-9.)!%]').hasMatch(last);
    _insert(closes ? ')' : '(', startsNewEntry: !closes);
  }

  void _equals() {
    final source = _input.trim();
    if (source.isEmpty) return;
    final CalcExpression parsed;
    try {
      parsed = CalcExpression.parse(source);
    } on CalcException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    if (parsed.usesX) {
      setState(() => _error = 'That has an x in it — press Plot to draw it.');
      return;
    }
    try {
      final value = parsed.evaluate(
        ans: _store.lastAnswer,
        degrees: _store.degrees,
      );
      final text = formatCalcNumber(value);
      _store.remember(source, text, value);
      setState(() {
        _answer = text;
        _answerIsFresh = true;
        _error = null;
        _second = false;
      });
    } on CalcException catch (e) {
      setState(() => _error = e.message);
    }
  }

  void _plot() {
    final source = _input.trim();
    if (source.isEmpty) {
      setState(() => _error = 'Type something like x^2 - 3 first.');
      return;
    }
    try {
      CalcExpression.parse(source);
    } on CalcException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    final added = _store.addFunction(source, nextGraphColor(_store.functions));
    setState(() {
      _error = added == null
          ? 'Local storage is full, so this function was not saved.'
          : null;
      if (added != null) {
        _input = '';
        _answer = null;
        _answerIsFresh = false;
        _showGraphTab = true;
      }
    });
  }

  /// The answer shown in grey under the entry while it's still being typed.
  String? get _livePreview {
    if (_input.trim().isEmpty || _answer != null) return null;
    final parsed = CalcExpression.tryParse(_input);
    if (parsed == null || parsed.usesX) return null;
    try {
      final value = parsed.evaluate(
        ans: _store.lastAnswer,
        degrees: _store.degrees,
      );
      final text = formatCalcNumber(value);
      return text == _input.trim() ? null : text;
    } on CalcException {
      return null;
    }
  }

  // ---- Physical keyboard ---------------------------------------------------

  static final _typedCharacter = RegExp(r'^[0-9a-zA-Z.+\-*/^()%!,]$');

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // The converter panel and any dialog own the keyboard while they're open.
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      return KeyEventResult.ignored;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.equal) {
      _equals();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.delete) {
      _clear();
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (character != null && _typedCharacter.hasMatch(character)) {
      _insert(character, startsNewEntry: RegExp(r'[0-9.]').hasMatch(character));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ---- Build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= _wideLayout;
        return Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            drawerEnableOpenDragGesture: false,
            drawer: UnitConverterDrawer(
              onUseValue: (value) =>
                  _insert(value, startsNewEntry: true),
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, wide),
                Expanded(
                  child: !_store.loaded
                      ? const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: _body(context, wide),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, bool wide) {
    final luma = context.luma;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: luma.border)),
      ),
      child: Row(
        children: [
          _HeaderButton(
            icon: Icons.menu_rounded,
            tooltip: 'Convert units',
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: LumaSegmentedTabs(
              tabs: const ['Basic', 'Advanced'],
              selectedIndex: _advanced ? 1 : 0,
              scrollable: true,
              onSelect: (index) => setState(() {
                _advanced = index == 1;
                _second = false;
              }),
            ),
          ),
          const SizedBox(width: 6),
          if (_advanced)
            _AngleToggle(
              degrees: _store.degrees,
              onChanged: _store.setDegrees,
            ),
          _HeaderButton(
            icon: Icons.history_rounded,
            tooltip: 'History',
            onTap: () => _showHistory(context),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, bool wide) {
    if (!_advanced) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _calculator(context),
        ),
      );
    }
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: GraphPanel(store: _store)),
          const SizedBox(width: 16),
          SizedBox(width: 420, child: _calculator(context)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LumaSegmentedTabs(
          tabs: const ['Keypad', 'Graph'],
          selectedIndex: _showGraphTab ? 1 : 0,
          onSelect: (index) => setState(() => _showGraphTab = index == 1),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _showGraphTab
              ? GraphPanel(store: _store)
              : _calculator(context),
        ),
      ],
    );
  }

  /// Display + keypad. When the window is too short for the keys to breathe,
  /// the whole column scrolls with fixed-height rows instead of squashing.
  Widget _calculator(BuildContext context) {
    final rows = _advanced ? _advancedRows : _basicRows;
    final minimumHeight = 132 + rows.length * 46 + (_advanced ? 60 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cramped = constraints.maxHeight < minimumHeight;
        final children = <Widget>[
          _Display(
            input: _input,
            answer: _answer,
            preview: _livePreview,
            error: _error,
            degrees: _store.degrees,
            advanced: _advanced,
          ),
          const SizedBox(height: 12),
          if (cramped)
            _Keypad(
              rows: rows,
              onPress: _press,
              second: _second,
              expand: false,
            )
          else
            Expanded(
              child: _Keypad(
                rows: rows,
                onPress: _press,
                second: _second,
                expand: true,
              ),
            ),
          if (_advanced) ...[
            const SizedBox(height: 10),
            LumaPrimaryButton(
              label: 'Plot as y = ${_input.trim().isEmpty ? '…' : _input.trim()}',
              icon: Icons.show_chart_rounded,
              expand: true,
              onTap: _plot,
            ),
          ],
        ];

        if (!cramped) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }

  void _press(_CalcKey key) {
    switch (key.action) {
      case _KeyAction.clear:
        _clear();
      case _KeyAction.backspace:
        _backspace();
      case _KeyAction.equals:
        _equals();
      case _KeyAction.brackets:
        _smartBracket();
      case _KeyAction.second:
        setState(() => _second = !_second);
      case null:
        _insert(
          key.insert ?? key.label,
          startsNewEntry: key.role == _KeyRole.value,
        );
    }
  }

  Future<void> _showHistory(BuildContext context) async {
    final luma = context.luma;
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: luma.surface,
        title: Row(
          children: [
            Expanded(
              child: Text(
                'History',
                style: TextStyle(color: luma.textPrimary, fontSize: 16),
              ),
            ),
            if (_store.history.isNotEmpty)
              TextButton(
                onPressed: () {
                  _store.clearHistory();
                  Navigator.of(dialogContext).pop();
                },
                child: Text('Clear', style: TextStyle(color: luma.danger)),
              ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: _store.history.isEmpty
              ? Text(
                  'Sums you work out show up here.',
                  style: TextStyle(color: luma.textMuted, fontSize: 13),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _store.history.length,
                  itemBuilder: (context, index) {
                    final entry = _store.history[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        entry.expression,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: luma.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        '= ${entry.result}',
                        style: TextStyle(
                          color: luma.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () =>
                          Navigator.of(dialogContext).pop(entry.expression),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Close', style: TextStyle(color: luma.textSecondary)),
          ),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _input = picked;
        _answer = null;
        _answerIsFresh = false;
        _error = null;
      });
    }
  }
}

// ---- Display ---------------------------------------------------------------

class _Display extends StatelessWidget {
  const _Display({
    required this.input,
    required this.answer,
    required this.preview,
    required this.error,
    required this.degrees,
    required this.advanced,
  });

  final String input;
  final String? answer;
  final String? preview;
  final String? error;
  final bool degrees;
  final bool advanced;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final secondLine = error ?? answer ?? preview;
    final isError = error != null;
    final isAnswer = error == null && answer != null;

    return LumaCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (advanced)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                degrees ? 'DEG' : 'RAD',
                style: TextStyle(
                  color: luma.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Text(
              input.isEmpty ? '0' : input,
              maxLines: 1,
              style: TextStyle(
                color: input.isEmpty ? luma.textMuted : luma.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: secondLine == null
                ? null
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        isError ? secondLine : '= $secondLine',
                        maxLines: 1,
                        style: TextStyle(
                          color: isError
                              ? luma.danger
                              : (isAnswer ? luma.textPrimary : luma.textMuted),
                          fontSize: isError ? 13.5 : (isAnswer ? 30 : 20),
                          fontWeight:
                              isAnswer ? FontWeight.w800 : FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---- Keypad ----------------------------------------------------------------

enum _KeyRole { value, operator, function, primary, warning }

enum _KeyAction { clear, backspace, equals, brackets, second }

class _CalcKey {
  const _CalcKey(
    this.label, {
    this.insert,
    this.role = _KeyRole.value,
    this.action,
    this.alternate,
  });

  final String label;

  /// What the key types into the entry; defaults to [label].
  final String? insert;

  final _KeyRole role;
  final _KeyAction? action;

  /// The key this one becomes while `2nd` is held on.
  final _CalcKey? alternate;
}

const _basicRows = <List<_CalcKey>>[
  [
    _CalcKey('AC', role: _KeyRole.warning, action: _KeyAction.clear),
    _CalcKey('⌫', role: _KeyRole.function, action: _KeyAction.backspace),
    _CalcKey('%', role: _KeyRole.operator),
    _CalcKey('÷', role: _KeyRole.operator),
  ],
  [
    _CalcKey('7'),
    _CalcKey('8'),
    _CalcKey('9'),
    _CalcKey('×', role: _KeyRole.operator),
  ],
  [
    _CalcKey('4'),
    _CalcKey('5'),
    _CalcKey('6'),
    _CalcKey('−', role: _KeyRole.operator),
  ],
  [
    _CalcKey('1'),
    _CalcKey('2'),
    _CalcKey('3'),
    _CalcKey('+', role: _KeyRole.operator),
  ],
  [
    _CalcKey('( )', role: _KeyRole.function, action: _KeyAction.brackets),
    _CalcKey('0'),
    _CalcKey('.'),
    _CalcKey('=', role: _KeyRole.primary, action: _KeyAction.equals),
  ],
];

const _advancedRows = <List<_CalcKey>>[
  [
    _CalcKey('2nd', role: _KeyRole.function, action: _KeyAction.second),
    _CalcKey('x'),
    _CalcKey('(', role: _KeyRole.function),
    _CalcKey(')', role: _KeyRole.function),
    _CalcKey('AC', role: _KeyRole.warning, action: _KeyAction.clear),
  ],
  [
    _CalcKey(
      'sin',
      insert: 'sin(',
      role: _KeyRole.function,
      alternate: _CalcKey('sin⁻¹', insert: 'asin(', role: _KeyRole.function),
    ),
    _CalcKey(
      'cos',
      insert: 'cos(',
      role: _KeyRole.function,
      alternate: _CalcKey('cos⁻¹', insert: 'acos(', role: _KeyRole.function),
    ),
    _CalcKey(
      'tan',
      insert: 'tan(',
      role: _KeyRole.function,
      alternate: _CalcKey('tan⁻¹', insert: 'atan(', role: _KeyRole.function),
    ),
    _CalcKey(
      '^',
      role: _KeyRole.operator,
      alternate: _CalcKey('ˣ√y', insert: 'root(', role: _KeyRole.operator),
    ),
    _CalcKey('⌫', role: _KeyRole.function, action: _KeyAction.backspace),
  ],
  [
    _CalcKey(
      'ln',
      insert: 'ln(',
      role: _KeyRole.function,
      alternate: _CalcKey('eˣ', insert: 'exp(', role: _KeyRole.function),
    ),
    _CalcKey(
      'log',
      insert: 'log(',
      role: _KeyRole.function,
      alternate: _CalcKey('10ˣ', insert: '10^(', role: _KeyRole.function),
    ),
    _CalcKey(
      '√',
      insert: '√(',
      role: _KeyRole.function,
      alternate: _CalcKey('x²', insert: '^2', role: _KeyRole.function),
    ),
    _CalcKey(
      'π',
      alternate: _CalcKey('τ', insert: 'tau'),
    ),
    _CalcKey(
      'e',
      alternate: _CalcKey('φ', insert: 'phi'),
    ),
  ],
  [
    _CalcKey('7'),
    _CalcKey('8'),
    _CalcKey('9'),
    _CalcKey('÷', role: _KeyRole.operator),
    _CalcKey(
      '%',
      role: _KeyRole.operator,
      alternate: _CalcKey('mod', insert: 'mod(', role: _KeyRole.operator),
    ),
  ],
  [
    _CalcKey('4'),
    _CalcKey('5'),
    _CalcKey('6'),
    _CalcKey('×', role: _KeyRole.operator),
    _CalcKey(
      '!',
      role: _KeyRole.operator,
      alternate: _CalcKey('nCr', insert: 'ncr(', role: _KeyRole.operator),
    ),
  ],
  [
    _CalcKey('1'),
    _CalcKey('2'),
    _CalcKey('3'),
    _CalcKey('−', role: _KeyRole.operator),
    _CalcKey('ANS', insert: 'ans', role: _KeyRole.function),
  ],
  [
    _CalcKey('0'),
    _CalcKey('.'),
    _CalcKey(',', role: _KeyRole.function),
    _CalcKey('+', role: _KeyRole.operator),
    _CalcKey('=', role: _KeyRole.primary, action: _KeyAction.equals),
  ],
];

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.rows,
    required this.onPress,
    required this.second,
    required this.expand,
  });

  final List<List<_CalcKey>> rows;
  final ValueChanged<_CalcKey> onPress;
  final bool second;

  /// True when the keypad has a bounded height to share out between its rows;
  /// false when it sits in a scroll view and needs fixed-height rows.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rows.length; row++)
          _KeypadRow(
            keys: rows[row],
            onPress: onPress,
            second: second,
            expand: expand,
            first: row == 0,
          ),
      ],
    );
  }
}

class _KeypadRow extends StatelessWidget {
  const _KeypadRow({
    required this.keys,
    required this.onPress,
    required this.second,
    required this.expand,
    required this.first,
  });

  final List<_CalcKey> keys;
  final ValueChanged<_CalcKey> onPress;
  final bool second;
  final bool expand;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: EdgeInsets.only(top: first ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _KeyButton(
                spec: second ? (keys[i].alternate ?? keys[i]) : keys[i],
                highlighted: second &&
                    (keys[i].action == _KeyAction.second ||
                        keys[i].alternate != null),
                onTap: onPress,
              ),
            ),
          ],
        ],
      ),
    );
    // Every row shares the spare height when there is some; in a scroll view
    // they're a fixed 56 tall instead (plus the 8px gap above all but the
    // first, which lives inside the box).
    return expand
        ? Expanded(child: row)
        : SizedBox(height: first ? 56 : 64, child: row);
  }
}

class _KeyButton extends StatefulWidget {
  const _KeyButton({
    required this.spec,
    required this.highlighted,
    required this.onTap,
  });

  final _CalcKey spec;
  final bool highlighted;
  final ValueChanged<_CalcKey> onTap;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    final spec = widget.spec;

    Color background;
    Color foreground;
    switch (spec.role) {
      case _KeyRole.primary:
        background = _hovering ? luma.accentHover : luma.accent;
        foreground = luma.onAccent;
      case _KeyRole.operator:
        background = _hovering ? luma.surfaceHover : luma.accentSubtle;
        foreground = luma.accent;
      case _KeyRole.warning:
        background = _hovering ? luma.surfaceHover : luma.surface;
        foreground = luma.danger;
      case _KeyRole.function:
        background = _hovering ? luma.surfaceHover : luma.surface;
        foreground = luma.textSecondary;
      case _KeyRole.value:
        background = _hovering ? luma.surfaceHover : luma.surface;
        foreground = luma.textPrimary;
    }
    if (widget.highlighted) {
      background = luma.accentSubtle;
      foreground = luma.accent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => widget.onTap(spec),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: spec.role == _KeyRole.primary
                  ? Colors.transparent
                  : luma.border,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                spec.label,
                style: TextStyle(
                  color: foreground,
                  fontSize: spec.label.length > 2 ? 15 : 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Header bits -----------------------------------------------------------

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: luma.textSecondary),
        ),
      ),
    );
  }
}

/// Degrees or radians, for everything trigonometric — the keypad and the plot
/// both follow it.
class _AngleToggle extends StatelessWidget {
  const _AngleToggle({required this.degrees, required this.onChanged});

  final bool degrees;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final luma = context.luma;
    return Tooltip(
      message: degrees ? 'Switch to radians' : 'Switch to degrees',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!degrees),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: luma.accentSubtle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            degrees ? 'DEG' : 'RAD',
            style: TextStyle(
              color: luma.accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
