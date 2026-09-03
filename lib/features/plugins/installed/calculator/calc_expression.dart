import 'dart:math' as math;

/// Thrown when an expression can't be read, parsed or evaluated. The message is
/// already written for the user — show `toString()` straight in the display.
class CalcException implements Exception {
  const CalcException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Values an expression can refer to while it is being evaluated: the graphing
/// variable `x`, the previous answer (`ans`), and whether the trig functions
/// work in degrees or radians.
class CalcEnv {
  const CalcEnv({this.x = 0, this.ans = 0, this.degrees = true});

  final double x;
  final double ans;
  final bool degrees;
}

/// A parsed expression, ready to be evaluated any number of times. Graphing
/// re-evaluates the same tree once per pixel column, so parsing is deliberately
/// separated from evaluation.
class CalcExpression {
  const CalcExpression._(this._root, this.source, this.usesX);

  final _Node _root;

  /// The text this was parsed from.
  final String source;

  /// Whether `x` appears anywhere — i.e. whether this is a plottable function
  /// rather than a plain sum.
  final bool usesX;

  /// Parses [source]. Throws [CalcException] with a readable message when the
  /// text isn't a valid expression.
  factory CalcExpression.parse(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) throw const CalcException('Nothing to work out yet.');
    final parser = _Parser(_tokenize(trimmed));
    final root = parser.parseAll();
    return CalcExpression._(root, trimmed, parser.usesX);
  }

  /// Same as [CalcExpression.parse] but returns null instead of throwing —
  /// used for the live preview under the entry line, where a half-typed
  /// expression is normal and shouldn't shout at anyone.
  static CalcExpression? tryParse(String source) {
    try {
      return CalcExpression.parse(source);
    } on CalcException {
      return null;
    }
  }

  double evaluate({double x = 0, double ans = 0, bool degrees = true}) =>
      _root.eval(CalcEnv(x: x, ans: ans, degrees: degrees));

  /// Parse-and-evaluate in one go, for one-shot sums.
  static double evaluateOnce(
    String source, {
    double ans = 0,
    bool degrees = true,
  }) =>
      CalcExpression.parse(source).evaluate(ans: ans, degrees: degrees);
}

// ---- Formatting ------------------------------------------------------------

/// Renders a result the way a calculator display should: whole numbers without
/// a decimal tail, float noise (0.1 + 0.2) rounded away, and very large or very
/// small values in scientific notation that this same parser can read back.
String formatCalcNumber(double value) {
  if (value.isNaN) return 'Undefined';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
  if (value == 0) return '0';

  final magnitude = value.abs();
  if (magnitude >= 1e12 || magnitude < 1e-9) {
    var text = value.toStringAsExponential(9);
    final parts = text.split('e');
    var mantissa = parts[0];
    if (mantissa.contains('.')) {
      mantissa = mantissa.replaceAll(RegExp(r'0+$'), '');
      if (mantissa.endsWith('.')) {
        mantissa = mantissa.substring(0, mantissa.length - 1);
      }
    }
    final exponent = parts[1].startsWith('+') ? parts[1].substring(1) : parts[1];
    return '${mantissa}e$exponent';
  }

  // 12 significant digits is a hair under a double's 15-16, which is exactly
  // what turns 0.30000000000000004 back into 0.3.
  final rounded = double.parse(value.toStringAsPrecision(12));
  if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
  var text = rounded.toString();
  if (text.contains('e')) text = rounded.toStringAsFixed(9);
  if (text.contains('.')) {
    text = text.replaceAll(RegExp(r'0+$'), '');
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  }
  return text;
}

// ---- Tokens ----------------------------------------------------------------

enum _TokenKind { number, name, symbol, end }

class _Token {
  const _Token(this.kind, this.text, [this.value = 0]);
  final _TokenKind kind;
  final String text;
  final double value;
}

const _symbols = '+-*/^(),!%';

bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

bool _isLetter(String c) {
  final code = c.codeUnitAt(0);
  return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
}

List<_Token> _tokenize(String input) {
  // Everything the keypad (or a paste) can contain gets folded down to the
  // plain ASCII the scanner below understands.
  final s = input
      .replaceAll('×', '*')
      .replaceAll('·', '*')
      .replaceAll('÷', '/')
      .replaceAll('−', '-')
      .replaceAll('–', '-')
      .replaceAll('π', 'pi')
      .replaceAll('τ', 'tau')
      .replaceAll('√', 'sqrt')
      .replaceAll('²', '^2')
      .replaceAll('³', '^3')
      .replaceAll('°', '');

  final tokens = <_Token>[];
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      i++;
      continue;
    }

    if (_isDigit(c) || (c == '.' && i + 1 < s.length && _isDigit(s[i + 1]))) {
      final start = i;
      while (i < s.length && _isDigit(s[i])) {
        i++;
      }
      if (i < s.length && s[i] == '.') {
        i++;
        while (i < s.length && _isDigit(s[i])) {
          i++;
        }
      }
      // An `e` only starts an exponent when digits actually follow it —
      // otherwise it's Euler's number, so `2e` stays 2 × e.
      if (i < s.length && (s[i] == 'e' || s[i] == 'E')) {
        var j = i + 1;
        if (j < s.length && (s[j] == '+' || s[j] == '-')) j++;
        if (j < s.length && _isDigit(s[j])) {
          while (j < s.length && _isDigit(s[j])) {
            j++;
          }
          i = j;
        }
      }
      final text = s.substring(start, i);
      final value = double.tryParse(text);
      if (value == null) throw CalcException('"$text" is not a number.');
      tokens.add(_Token(_TokenKind.number, text, value));
      continue;
    }

    if (_isLetter(c)) {
      final start = i;
      while (i < s.length && _isLetter(s[i])) {
        i++;
      }
      var name = s.substring(start, i).toLowerCase();
      // Digits belong to the name only when they complete a known one
      // (`log2`), so `x2` still reads as x × 2.
      if (i < s.length && _isDigit(s[i])) {
        var j = i;
        while (j < s.length && _isDigit(s[j])) {
          j++;
        }
        final extended = s.substring(start, j).toLowerCase();
        if (_functions.containsKey(extended)) {
          name = extended;
          i = j;
        }
      }
      for (final part in _splitName(name)) {
        tokens.add(_Token(_TokenKind.name, part));
      }
      continue;
    }

    if (_symbols.contains(c)) {
      tokens.add(_Token(_TokenKind.symbol, c));
      i++;
      continue;
    }

    throw CalcException('I don\'t understand "$c".');
  }

  tokens.add(const _Token(_TokenKind.end, ''));
  return tokens;
}

/// Breaks a run of letters into known names so typing `sinx` or `2pir` works
/// without spelling out every multiplication.
List<String> _splitName(String name) {
  if (_isKnownName(name)) return [name];
  final parts = <String>[];
  var start = 0;
  while (start < name.length) {
    var matched = 0;
    for (var end = name.length; end > start; end--) {
      if (_isKnownName(name.substring(start, end))) {
        matched = end - start;
        break;
      }
    }
    if (matched == 0) throw CalcException('I don\'t know "$name".');
    parts.add(name.substring(start, start + matched));
    start += matched;
  }
  return parts;
}

bool _isKnownName(String name) =>
    _functions.containsKey(name) ||
    _constants.containsKey(name) ||
    name == 'x' ||
    name == 'ans';

// ---- Parser ----------------------------------------------------------------

/// Recursive descent, lowest precedence first:
///
///     expression → term (('+' | '-') term)*
///     term       → unary (('*' | '/') unary | unary)*     ← bare unary = implicit ×
///     unary      → ('-' | '+') unary | power
///     power      → postfix ('^' unary)?                   ← right associative
///     postfix    → primary ('!' | '%')*
///     primary    → number | constant | variable | call | '(' expression ')'
class _Parser {
  _Parser(this._tokens);

  final List<_Token> _tokens;
  int _pos = 0;
  bool usesX = false;

  _Token get _peek => _tokens[_pos];
  _Token _advance() => _tokens[_pos++];

  bool _isSymbol(String text) =>
      _peek.kind == _TokenKind.symbol && _peek.text == text;

  _Node parseAll() {
    final node = _expression();
    if (_peek.kind != _TokenKind.end) {
      throw CalcException('"${_peek.text}" doesn\'t belong there.');
    }
    return node;
  }

  _Node _expression() {
    var left = _term();
    while (_isSymbol('+') || _isSymbol('-')) {
      final op = _advance().text;
      left = _Binary(op, left, _term());
    }
    return left;
  }

  _Node _term() {
    var left = _unary();
    while (true) {
      if (_isSymbol('*') || _isSymbol('/')) {
        final op = _advance().text;
        left = _Binary(op, left, _unary());
      } else if (_startsFactor()) {
        left = _Binary('*', left, _unary());
      } else {
        return left;
      }
    }
  }

  /// True when the next token can only begin a new factor, which is how
  /// `2x`, `3(4+1)` and `2sin(x)` become multiplications.
  bool _startsFactor() =>
      _peek.kind == _TokenKind.number ||
      _peek.kind == _TokenKind.name ||
      _isSymbol('(');

  _Node _unary() {
    if (_isSymbol('-')) {
      _advance();
      return _Negate(_unary());
    }
    if (_isSymbol('+')) {
      _advance();
      return _unary();
    }
    return _power();
  }

  _Node _power() {
    final base = _postfix();
    if (_isSymbol('^')) {
      _advance();
      return _Binary('^', base, _unary());
    }
    return base;
  }

  _Node _postfix() {
    var node = _primary();
    while (_isSymbol('!') || _isSymbol('%')) {
      node = _Postfix(_advance().text, node);
    }
    return node;
  }

  _Node _primary() {
    final token = _peek;
    switch (token.kind) {
      case _TokenKind.number:
        _advance();
        return _Literal(token.value);

      case _TokenKind.name:
        _advance();
        final constant = _constants[token.text];
        if (constant != null) return _Literal(constant);
        if (token.text == 'x') {
          usesX = true;
          return const _Variable(true);
        }
        if (token.text == 'ans') return const _Variable(false);
        return _call(token.text);

      case _TokenKind.symbol:
        if (token.text == '(') {
          _advance();
          final inner = _expression();
          _expect(')');
          return inner;
        }
        throw CalcException('"${token.text}" doesn\'t belong there.');

      case _TokenKind.end:
        throw const CalcException('The expression stops too early.');
    }
  }

  _Node _call(String name) {
    final function = _functions[name];
    if (function == null) throw CalcException('I don\'t know "$name".');

    final args = <_Node>[];
    if (_isSymbol('(')) {
      _advance();
      if (!_isSymbol(')')) {
        args.add(_expression());
        while (_isSymbol(',')) {
          _advance();
          args.add(_expression());
        }
      }
      _expect(')');
    } else {
      // `sin x` and `√9` — a function without brackets takes the next power,
      // so `sin x^2` is sin(x²) and `sin x cos x` is a product of two calls.
      args.add(_power());
    }

    if (args.length < function.minArgs || args.length > function.maxArgs) {
      throw CalcException(
        function.minArgs == function.maxArgs
            ? '$name needs ${function.minArgs} value(s).'
            : '$name needs ${function.minArgs} to ${function.maxArgs} values.',
      );
    }
    return _Call(name, function, args);
  }

  void _expect(String symbol) {
    if (!_isSymbol(symbol)) {
      throw CalcException(
        symbol == ')' ? 'A bracket is left open.' : 'Expected "$symbol".',
      );
    }
    _advance();
  }
}

// ---- Nodes -----------------------------------------------------------------

abstract class _Node {
  const _Node();
  double eval(CalcEnv env);
}

class _Literal extends _Node {
  const _Literal(this.value);
  final double value;

  @override
  double eval(CalcEnv env) => value;
}

class _Variable extends _Node {
  const _Variable(this.isX);
  final bool isX;

  @override
  double eval(CalcEnv env) => isX ? env.x : env.ans;
}

class _Negate extends _Node {
  const _Negate(this.child);
  final _Node child;

  @override
  double eval(CalcEnv env) => -child.eval(env);
}

class _Binary extends _Node {
  const _Binary(this.op, this.left, this.right);
  final String op;
  final _Node left;
  final _Node right;

  @override
  double eval(CalcEnv env) {
    final a = left.eval(env);
    final b = right.eval(env);
    switch (op) {
      case '+':
        return a + b;
      case '-':
        return a - b;
      case '*':
        return a * b;
      case '/':
        return a / b;
      case '^':
        return _power(a, b);
    }
    throw CalcException('Unknown operator "$op".');
  }
}

class _Postfix extends _Node {
  const _Postfix(this.op, this.child);
  final String op;
  final _Node child;

  @override
  double eval(CalcEnv env) {
    final value = child.eval(env);
    return op == '!' ? _factorial(value) : value / 100;
  }
}

class _Call extends _Node {
  const _Call(this.name, this.function, this.args);
  final String name;
  final _Function function;
  final List<_Node> args;

  @override
  double eval(CalcEnv env) {
    final values = <double>[for (final arg in args) arg.eval(env)];
    return function.apply(values, env);
  }
}

// ---- Built-ins -------------------------------------------------------------

class _Function {
  const _Function(this.minArgs, this.maxArgs, this.apply);
  final int minArgs;
  final int maxArgs;
  final double Function(List<double> args, CalcEnv env) apply;
}

const _constants = <String, double>{
  'pi': math.pi,
  'tau': math.pi * 2,
  'e': math.e,
  'phi': 1.6180339887498948,
};

double _toRadians(double value, CalcEnv env) =>
    env.degrees ? value * math.pi / 180 : value;

double _fromRadians(double value, CalcEnv env) =>
    env.degrees ? value * 180 / math.pi : value;

/// `x ^ y`, with the whole-number negative-base case (`(-8)^(1/3)`) handled the
/// way a calculator should rather than returning NaN.
double _power(double base, double exponent) {
  if (base < 0 && exponent != exponent.roundToDouble()) {
    final inverse = 1 / exponent;
    if ((inverse - inverse.roundToDouble()).abs() < 1e-9 &&
        inverse.round().isOdd) {
      return -math.pow(-base, exponent).toDouble();
    }
  }
  return math.pow(base, exponent).toDouble();
}

double _factorial(double value) {
  if (value < 0 || value != value.roundToDouble()) {
    throw const CalcException('Factorial only works on whole numbers from 0.');
  }
  if (value > 170) return double.infinity;
  var result = 1.0;
  for (var i = 2; i <= value.toInt(); i++) {
    result *= i;
  }
  return result;
}

double _combinations(double n, double r) {
  if (n < 0 || r < 0 || n != n.roundToDouble() || r != r.roundToDouble()) {
    throw const CalcException('nCr and nPr need whole numbers from 0.');
  }
  if (r > n) return 0;
  final k = math.min(r, n - r).toInt();
  var result = 1.0;
  for (var i = 1; i <= k; i++) {
    result = result * (n - k + i) / i;
  }
  return result.roundToDouble();
}

double _permutations(double n, double r) {
  if (n < 0 || r < 0 || n != n.roundToDouble() || r != r.roundToDouble()) {
    throw const CalcException('nCr and nPr need whole numbers from 0.');
  }
  if (r > n) return 0;
  var result = 1.0;
  for (var i = 0; i < r.toInt(); i++) {
    result *= n - i;
  }
  return result;
}

double _greatestCommonDivisor(double a, double b) {
  var x = a.abs().roundToDouble();
  var y = b.abs().roundToDouble();
  while (y > 0) {
    final remainder = x % y;
    x = y;
    y = remainder;
  }
  return x;
}

final _functions = <String, _Function>{
  'sin': _Function(1, 1, (a, env) => math.sin(_toRadians(a[0], env))),
  'cos': _Function(1, 1, (a, env) => math.cos(_toRadians(a[0], env))),
  'tan': _Function(1, 1, (a, env) => math.tan(_toRadians(a[0], env))),
  'asin': _Function(1, 1, (a, env) => _fromRadians(math.asin(a[0]), env)),
  'acos': _Function(1, 1, (a, env) => _fromRadians(math.acos(a[0]), env)),
  'atan': _Function(1, 1, (a, env) => _fromRadians(math.atan(a[0]), env)),
  'atan2':
      _Function(2, 2, (a, env) => _fromRadians(math.atan2(a[0], a[1]), env)),
  'sinh': _Function(
      1, 1, (a, env) => (math.exp(a[0]) - math.exp(-a[0])) / 2),
  'cosh': _Function(
      1, 1, (a, env) => (math.exp(a[0]) + math.exp(-a[0])) / 2),
  'tanh': _Function(1, 1, (a, env) {
    if (a[0] > 20) return 1;
    if (a[0] < -20) return -1;
    final positive = math.exp(a[0]);
    final negative = math.exp(-a[0]);
    return (positive - negative) / (positive + negative);
  }),
  'ln': _Function(1, 1, (a, env) => math.log(a[0])),
  'log': _Function(1, 1, (a, env) => math.log(a[0]) / math.ln10),
  'log2': _Function(1, 1, (a, env) => math.log(a[0]) / math.ln2),
  'logb': _Function(2, 2, (a, env) => math.log(a[1]) / math.log(a[0])),
  'exp': _Function(1, 1, (a, env) => math.exp(a[0])),
  'sqrt': _Function(1, 1, (a, env) => math.sqrt(a[0])),
  'cbrt': _Function(1, 1, (a, env) => _power(a[0], 1 / 3)),
  'root': _Function(2, 2, (a, env) => _power(a[1], 1 / a[0])),
  'abs': _Function(1, 1, (a, env) => a[0].abs()),
  'sign': _Function(1, 1, (a, env) => a[0] == 0 ? 0 : (a[0] < 0 ? -1 : 1)),
  'floor': _Function(1, 1, (a, env) => a[0].floorToDouble()),
  'ceil': _Function(1, 1, (a, env) => a[0].ceilToDouble()),
  'round': _Function(1, 2, (a, env) {
    if (a.length == 1) return a[0].roundToDouble();
    final factor = math.pow(10, a[1].round()).toDouble();
    return (a[0] * factor).roundToDouble() / factor;
  }),
  'trunc': _Function(1, 1, (a, env) => a[0].truncateToDouble()),
  'mod': _Function(2, 2, (a, env) => a[0] % a[1]),
  'pow': _Function(2, 2, (a, env) => _power(a[0], a[1])),
  'hypot': _Function(
      2, 2, (a, env) => math.sqrt(a[0] * a[0] + a[1] * a[1])),
  'min': _Function(1, 8, (a, env) => a.reduce(math.min)),
  'max': _Function(1, 8, (a, env) => a.reduce(math.max)),
  'fact': _Function(1, 1, (a, env) => _factorial(a[0])),
  'ncr': _Function(2, 2, (a, env) => _combinations(a[0], a[1])),
  'npr': _Function(2, 2, (a, env) => _permutations(a[0], a[1])),
  'gcd': _Function(2, 2, (a, env) => _greatestCommonDivisor(a[0], a[1])),
  'lcm': _Function(2, 2, (a, env) {
    final divisor = _greatestCommonDivisor(a[0], a[1]);
    if (divisor == 0) return 0;
    return (a[0] * a[1] / divisor).abs();
  }),
};
