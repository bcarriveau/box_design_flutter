/// Evaluates a simple arithmetic expression typed into a numeric field --
/// "+", "-", "*", "/", parentheses, and unary +/- (e.g. "55-23", "(10+2)*3")
/// -- falling back to a plain [double.tryParse] first so the common case of
/// just typing a number never pays for tokenizing. Returns null for
/// anything that isn't a valid number or expression (including division by
/// zero, or trailing garbage after a valid expression), so callers can
/// treat it exactly like [double.tryParse].
double? tryEvalMath(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final direct = double.tryParse(trimmed);
  if (direct != null) return direct;

  final parser = _ExprParser(trimmed);
  double value;
  try {
    value = parser._parseExpr();
    parser._skipSpaces();
  } on FormatException {
    return null;
  }
  if (!parser._atEnd || value.isNaN || value.isInfinite) return null;
  return value;
}

class _ExprParser {
  _ExprParser(this._input);
  final String _input;
  int _pos = 0;

  bool get _atEnd => _pos >= _input.length;

  void _skipSpaces() {
    while (!_atEnd && _input[_pos] == ' ') {
      _pos++;
    }
  }

  double _parseExpr() {
    var value = _parseTerm();
    while (true) {
      _skipSpaces();
      if (_atEnd) break;
      final c = _input[_pos];
      if (c == '+') {
        _pos++;
        value += _parseTerm();
      } else if (c == '-') {
        _pos++;
        value -= _parseTerm();
      } else {
        break;
      }
    }
    return value;
  }

  double _parseTerm() {
    var value = _parseFactor();
    while (true) {
      _skipSpaces();
      if (_atEnd) break;
      final c = _input[_pos];
      if (c == '*') {
        _pos++;
        value *= _parseFactor();
      } else if (c == '/') {
        _pos++;
        final divisor = _parseFactor();
        if (divisor == 0) throw const FormatException('division by zero');
        value /= divisor;
      } else {
        break;
      }
    }
    return value;
  }

  double _parseFactor() {
    _skipSpaces();
    if (!_atEnd && _input[_pos] == '+') {
      _pos++;
      return _parseFactor();
    }
    if (!_atEnd && _input[_pos] == '-') {
      _pos++;
      return -_parseFactor();
    }
    return _parsePrimary();
  }

  double _parsePrimary() {
    _skipSpaces();
    if (_atEnd) throw const FormatException('unexpected end of expression');
    if (_input[_pos] == '(') {
      _pos++;
      final value = _parseExpr();
      _skipSpaces();
      if (_atEnd || _input[_pos] != ')') throw const FormatException('expected )');
      _pos++;
      return value;
    }
    final start = _pos;
    while (!_atEnd && (_isDigit(_input[_pos]) || _input[_pos] == '.')) {
      _pos++;
    }
    if (_pos == start) throw const FormatException('expected a number');
    final value = double.tryParse(_input.substring(start, _pos));
    if (value == null) throw const FormatException('invalid number');
    return value;
  }

  bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}
