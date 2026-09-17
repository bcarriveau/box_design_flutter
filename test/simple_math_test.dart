import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/services/simple_math.dart';

void main() {
  test('parses a plain number without going through the expression parser', () {
    expect(tryEvalMath('42'), 42);
    expect(tryEvalMath('-3.5'), -3.5);
  });

  test('evaluates simple subtraction, matching the reported use case', () {
    expect(tryEvalMath('55-23'), 32);
  });

  test('evaluates all four operators with standard precedence', () {
    expect(tryEvalMath('2+3*4'), 14);
    expect(tryEvalMath('(2+3)*4'), 20);
    expect(tryEvalMath('10/2-1'), 4);
  });

  test('handles unary minus and whitespace', () {
    expect(tryEvalMath('-5+10'), 5);
    expect(tryEvalMath(' 55 - 23 '), 32);
  });

  test('returns null for division by zero', () {
    expect(tryEvalMath('5/0'), isNull);
  });

  test('returns null for garbage, empty input, or trailing junk', () {
    expect(tryEvalMath(''), isNull);
    expect(tryEvalMath('abc'), isNull);
    expect(tryEvalMath('5+'), isNull);
    expect(tryEvalMath('5 5'), isNull);
    expect(tryEvalMath('(5+2'), isNull);
  });
}
