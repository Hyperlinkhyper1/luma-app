import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:luma/features/plugins/installed/calculator/calc_expression.dart';
import 'package:luma/features/plugins/installed/calculator/unit_conversion.dart';

double eval(String source, {double x = 0, double ans = 0, bool degrees = true}) =>
    CalcExpression.parse(source).evaluate(x: x, ans: ans, degrees: degrees);

void main() {
  group('arithmetic', () {
    test('follows the usual order of operations', () {
      expect(eval('2+3*4'), 14);
      expect(eval('(2+3)*4'), 20);
      expect(eval('7-3-2'), 2);
      expect(eval('100/10/2'), 5);
    });

    test('powers are right associative and beat unary minus', () {
      expect(eval('2^3^2'), 512);
      expect(eval('-2^2'), -4);
      expect(eval('(-2)^2'), 4);
      expect(eval('2^-3'), 0.125);
    });

    test('a missing × between factors is implied', () {
      expect(eval('2x', x: 4), 8);
      expect(eval('2(3+4)'), 14);
      expect(eval('(1+1)(2+2)'), 8);
      expect(eval('2x^2', x: 3), 18);
      expect(eval('3pi'), closeTo(3 * math.pi, 1e-12));
    });

    test('reads the symbols the keypad types', () {
      expect(eval('6×7'), 42);
      expect(eval('84÷2'), 42);
      expect(eval('10−4'), 6);
      expect(eval('√16'), 4);
      expect(eval('2√9'), 6);
      expect(eval('5²'), 25);
      expect(eval('π'), closeTo(math.pi, 1e-12));
    });

    test('handles factorial and percent', () {
      expect(eval('5!'), 120);
      expect(eval('0!'), 1);
      expect(eval('50%'), 0.5);
      expect(eval('200*10%'), 20);
    });
  });

  group('functions', () {
    test('trig follows the angle mode', () {
      expect(eval('sin(30)'), closeTo(0.5, 1e-12));
      expect(eval('sin(pi/2)', degrees: false), closeTo(1, 1e-12));
      expect(eval('asin(0.5)'), closeTo(30, 1e-12));
      expect(eval('atan(1)'), closeTo(45, 1e-12));
    });

    test('a function without brackets takes the next power', () {
      expect(eval('sin x', x: 30), closeTo(0.5, 1e-12));
      expect(eval('sinx', x: 30), closeTo(0.5, 1e-12));
      expect(eval('sin(30)cos(60)'), closeTo(0.25, 1e-12));
    });

    test('logs, roots and the rest', () {
      expect(eval('log(1000)'), closeTo(3, 1e-12));
      expect(eval('ln(e)'), closeTo(1, 1e-12));
      expect(eval('log2(1024)'), closeTo(10, 1e-12));
      expect(eval('logb(3,81)'), closeTo(4, 1e-12));
      expect(eval('cbrt(-27)'), closeTo(-3, 1e-12));
      expect(eval('root(3,27)'), closeTo(3, 1e-12));
      expect(eval('hypot(3,4)'), 5);
      expect(eval('mod(10,3)'), 1);
      expect(eval('ncr(5,2)'), 10);
      expect(eval('npr(5,2)'), 20);
      expect(eval('gcd(12,18)'), 6);
      expect(eval('round(2.567,2)'), closeTo(2.57, 1e-12));
    });

    test('ans carries the previous answer', () {
      expect(eval('ans*2', ans: 42), 84);
    });
  });

  group('parsing', () {
    test('spots which expressions are functions of x', () {
      expect(CalcExpression.parse('x^2').usesX, isTrue);
      expect(CalcExpression.parse('2+2').usesX, isFalse);
    });

    test('rejects nonsense with a readable message', () {
      expect(() => eval('2+'), throwsA(isA<CalcException>()));
      expect(() => eval('(1+2'), throwsA(isA<CalcException>()));
      expect(() => eval('1+2)'), throwsA(isA<CalcException>()));
      expect(() => eval('foo(2)'), throwsA(isA<CalcException>()));
      expect(() => eval(''), throwsA(isA<CalcException>()));
      expect(() => eval('(-1)!'), throwsA(isA<CalcException>()));
    });

    test('tryParse returns null instead of throwing', () {
      expect(CalcExpression.tryParse('2+'), isNull);
      expect(CalcExpression.tryParse('2+2'), isNotNull);
    });

    test('undefined results stay non-finite so a graph can break the line', () {
      expect(eval('1/0'), double.infinity);
      expect(eval('0/0').isNaN, isTrue);
      expect(eval('sqrt(-1)').isNaN, isTrue);
    });

    test('an e between digits is an exponent, on its own it is Euler', () {
      expect(eval('1.5e3'), 1500);
      expect(eval('2e-3'), closeTo(0.002, 1e-15));
      expect(eval('2e'), closeTo(2 * math.e, 1e-12));
    });
  });

  group('formatting', () {
    test('whole numbers lose their decimal tail', () {
      expect(formatCalcNumber(3), '3');
      expect(formatCalcNumber(0), '0');
      expect(formatCalcNumber(999999999999), '999999999999');
    });

    test('float noise is rounded away', () {
      expect(formatCalcNumber(0.1 + 0.2), '0.3');
      expect(formatCalcNumber(2.0000000000000004), '2');
      expect(formatCalcNumber(1 / 3), '0.333333333333');
    });

    test('extremes use scientific notation this parser can read back', () {
      expect(formatCalcNumber(1e21), '1e21');
      expect(formatCalcNumber(1.5e-12), '1.5e-12');
      expect(eval(formatCalcNumber(1e21)), 1e21);
    });

    test('undefined answers say so', () {
      expect(formatCalcNumber(double.nan), 'Undefined');
      expect(formatCalcNumber(double.infinity), '∞');
      expect(formatCalcNumber(double.negativeInfinity), '-∞');
    });
  });

  group('unit conversion', () {
    ConvertUnit unit(String category, String id) =>
        categoryById(category).unitById(id);

    test('kilometres to miles', () {
      expect(
        convertUnits(1, unit('length', 'km'), unit('length', 'mi')),
        closeTo(0.621371192, 1e-9),
      );
      expect(
        convertUnits(42.195, unit('length', 'km'), unit('length', 'mi')),
        closeTo(26.21875746, 1e-7),
      );
    });

    test('temperature carries its offset both ways', () {
      final celsius = unit('temperature', 'c');
      final fahrenheit = unit('temperature', 'f');
      final kelvin = unit('temperature', 'k');
      expect(convertUnits(0, celsius, fahrenheit), closeTo(32, 1e-9));
      expect(convertUnits(100, celsius, fahrenheit), closeTo(212, 1e-9));
      expect(convertUnits(-40, celsius, fahrenheit), closeTo(-40, 1e-9));
      expect(convertUnits(0, celsius, kelvin), closeTo(273.15, 1e-9));
      expect(convertUnits(98.6, fahrenheit, celsius), closeTo(37, 1e-9));
    });

    test('weight, speed and data', () {
      expect(
        convertUnits(1, unit('mass', 'kg'), unit('mass', 'lb')),
        closeTo(2.20462262, 1e-8),
      );
      expect(
        convertUnits(100, unit('speed', 'kmh'), unit('speed', 'mph')),
        closeTo(62.1371192, 1e-7),
      );
      expect(
        convertUnits(1, unit('data', 'gib'), unit('data', 'gb')),
        closeTo(1.073741824, 1e-9),
      );
    });

    test('converting to the same unit changes nothing', () {
      for (final category in unitCategories) {
        for (final u in category.units) {
          expect(convertUnits(7.5, u, u), closeTo(7.5, 1e-9),
              reason: '${category.name} / ${u.name}');
        }
      }
    });

    test('every unit id in a category is unique', () {
      for (final category in unitCategories) {
        final ids = category.units.map((u) => u.id).toSet();
        expect(ids.length, category.units.length, reason: category.name);
      }
    });
  });
}
