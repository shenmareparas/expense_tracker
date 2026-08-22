import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/utils/math_evaluator.dart';

void main() {
  group('MathEvaluator', () {
    test('evaluates simple numbers', () {
      expect(MathEvaluator.evaluate('100'), 100.0);
      expect(MathEvaluator.evaluate(' 250.50 '), 250.5);
      expect(MathEvaluator.evaluate('0'), 0.0);
    });

    test('evaluates addition and subtraction', () {
      expect(MathEvaluator.evaluate('50 + 20'), 70.0);
      expect(MathEvaluator.evaluate('100 - 35'), 65.0);
      expect(MathEvaluator.evaluate('100 - 30 + 15'), 85.0);
      expect(MathEvaluator.evaluate('10.5 + 20.25 - 5'), 25.75);
    });

    test('evaluates multiplication and division with precedence', () {
      expect(MathEvaluator.evaluate('10 + 5 * 2'), 20.0);
      expect(MathEvaluator.evaluate('50 - 20 / 4'), 45.0);
      expect(MathEvaluator.evaluate('10 * 4 / 2'), 20.0);
    });

    test('handles parentheses', () {
      expect(MathEvaluator.evaluate('(10 + 5) * 2'), 30.0);
      expect(MathEvaluator.evaluate('100 / (2 + 3)'), 20.0);
    });

    test('handles unary operators', () {
      expect(MathEvaluator.evaluate('-50 + 100'), 50.0);
      expect(MathEvaluator.evaluate('+50 + 50'), 100.0);
      expect(MathEvaluator.evaluate('50 + -20'), 30.0);
    });

    test('handles unicode operators and symbols', () {
      expect(MathEvaluator.evaluate('₹50 + ₹25'), 75.0);
      expect(MathEvaluator.evaluate('10 × 5 ÷ 2'), 25.0);
      expect(MathEvaluator.evaluate('100 − 40'), 60.0);
    });

    test('returns null for invalid inputs or division by zero', () {
      expect(MathEvaluator.evaluate(''), isNull);
      expect(MathEvaluator.evaluate('   '), isNull);
      expect(MathEvaluator.evaluate('50+'), isNull);
      expect(MathEvaluator.evaluate('100 / 0'), isNull);
      expect(MathEvaluator.evaluate('abc'), isNull);
      expect(MathEvaluator.evaluate('50..5'), isNull);
      expect(MathEvaluator.evaluate('(50 + 20'), isNull);
    });

    test('formats values cleanly', () {
      expect(MathEvaluator.format(100.0), '100');
      expect(MathEvaluator.format(100.5), '100.5');
      expect(MathEvaluator.format(100.25), '100.25');
      expect(MathEvaluator.format(100.20), '100.2');
      expect(MathEvaluator.format(33.33333), '33.33');
      expect(MathEvaluator.format(0.0), '0');
    });
  });
}
