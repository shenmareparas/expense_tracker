enum _TokenType {
  number,
  plus,
  minus,
  multiply,
  divide,
  openParen,
  closeParen,
}

class _Token {
  final _TokenType type;
  final double? value;

  _Token(this.type, [this.value]);
}

class MathEvaluator {
  /// Evaluates an arithmetic expression string (e.g., "50 + 20 - 5 * 2").
  /// Returns `null` if the expression is invalid, empty, or divides by zero.
  static double? evaluate(String expression) {
    final tokens = _tokenize(expression);
    if (tokens == null || tokens.isEmpty) return null;
    return _Parser(tokens).parse();
  }

  /// Formats a numeric value as a clean string without redundant trailing zeros.
  /// Examples: 50.0 -> "50", 12.5 -> "12.5", 33.3333 -> "33.33"
  static String format(double value) {
    if (value.isInfinite || value.isNaN) return '';
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    String str = value.toStringAsFixed(2);
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return str;
  }

  static List<_Token>? _tokenize(String input) {
    final tokens = <_Token>[];
    int i = 0;
    final sanitized = input
        .replaceAll('₹', '')
        .replaceAll('\$', '')
        .replaceAll(',', '')
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('−', '-');

    while (i < sanitized.length) {
      final char = sanitized[i];
      if (char.trim().isEmpty) {
        i++;
        continue;
      }
      if (char == '+') {
        tokens.add(_Token(_TokenType.plus));
        i++;
      } else if (char == '-') {
        tokens.add(_Token(_TokenType.minus));
        i++;
      } else if (char == '*') {
        tokens.add(_Token(_TokenType.multiply));
        i++;
      } else if (char == '/') {
        tokens.add(_Token(_TokenType.divide));
        i++;
      } else if (char == '(') {
        tokens.add(_Token(_TokenType.openParen));
        i++;
      } else if (char == ')') {
        tokens.add(_Token(_TokenType.closeParen));
        i++;
      } else if (RegExp(r'[0-9.]').hasMatch(char)) {
        int start = i;
        int dotCount = 0;
        while (i < sanitized.length && RegExp(r'[0-9.]').hasMatch(sanitized[i])) {
          if (sanitized[i] == '.') dotCount++;
          if (dotCount > 1) return null;
          i++;
        }
        final numStr = sanitized.substring(start, i);
        if (numStr == '.') return null;
        final val = double.tryParse(numStr);
        if (val == null) return null;
        tokens.add(_Token(_TokenType.number, val));
      } else {
        return null;
      }
    }
    return tokens;
  }
}

class _Parser {
  final List<_Token> tokens;
  int _pos = 0;

  _Parser(this.tokens);

  _Token? get _current => _pos < tokens.length ? tokens[_pos] : null;

  _Token? _consume(_TokenType type) {
    if (_current?.type == type) {
      final t = _current;
      _pos++;
      return t;
    }
    return null;
  }

  double? parse() {
    if (tokens.isEmpty) return null;
    final result = _parseExpression();
    if (result == null || _pos != tokens.length) return null;
    if (result.isNaN || result.isInfinite) return null;
    return result;
  }

  double? _parseExpression() {
    var left = _parseTerm();
    if (left == null) return null;

    while (_current != null &&
        (_current!.type == _TokenType.plus ||
            _current!.type == _TokenType.minus)) {
      final op = _current!.type;
      _pos++;
      final right = _parseTerm();
      if (right == null) return null;
      if (op == _TokenType.plus) {
        left = left! + right;
      } else {
        left = left! - right;
      }
    }
    return left;
  }

  double? _parseTerm() {
    var left = _parseFactor();
    if (left == null) return null;

    while (_current != null &&
        (_current!.type == _TokenType.multiply ||
            _current!.type == _TokenType.divide)) {
      final op = _current!.type;
      _pos++;
      final right = _parseFactor();
      if (right == null) return null;
      if (op == _TokenType.multiply) {
        left = left! * right;
      } else {
        if (right == 0) return null;
        left = left! / right;
      }
    }
    return left;
  }

  double? _parseFactor() {
    if (_current == null) return null;

    if (_current!.type == _TokenType.plus) {
      _pos++;
      return _parseFactor();
    }
    if (_current!.type == _TokenType.minus) {
      _pos++;
      final val = _parseFactor();
      return val != null ? -val : null;
    }

    if (_current!.type == _TokenType.number) {
      final val = _current!.value;
      _pos++;
      return val;
    }

    if (_consume(_TokenType.openParen) != null) {
      final val = _parseExpression();
      if (val == null || _consume(_TokenType.closeParen) == null) {
        return null;
      }
      return val;
    }

    return null;
  }
}
