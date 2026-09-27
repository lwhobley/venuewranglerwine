class DecimalAmount implements Comparable<DecimalAmount> {
  const DecimalAmount._(this._minor, this.scale);

  final BigInt _minor;
  final int scale;

  static final _pattern = RegExp(r'^-?\d+(\.\d+)?$');

  factory DecimalAmount.parse(String raw, {int scale = 4}) {
    if (scale < 0 || scale > 8) {
      throw FormatException('Unsupported scale $scale');
    }
    final trimmed = raw.trim();
    if (!_pattern.hasMatch(trimmed)) {
      throw FormatException('Invalid decimal amount');
    }
    final negative = trimmed.startsWith('-');
    final body = negative ? trimmed.substring(1) : trimmed;
    final parts = body.split('.');
    final whole = parts[0];
    final fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.length > scale) {
      throw FormatException('Scale exceeds $scale');
    }
    final padded = fraction.padRight(scale, '0');
    final digits = '$whole$padded'.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    var minor = BigInt.parse(digits.isEmpty ? '0' : digits);
    if (negative) minor = -minor;
    return DecimalAmount._(minor, scale);
  }

  factory DecimalAmount.zero({int scale = 4}) {
    return DecimalAmount._(BigInt.zero, scale);
  }

  bool get isNegative => _minor.isNegative;

  DecimalAmount plus(DecimalAmount other) {
    _requireSameScale(other);
    return DecimalAmount._(_minor + other._minor, scale);
  }

  DecimalAmount minus(DecimalAmount other) {
    _requireSameScale(other);
    return DecimalAmount._(_minor - other._minor, scale);
  }

  bool operator >(DecimalAmount other) => compareTo(other) > 0;

  @override
  int compareTo(DecimalAmount other) {
    _requireSameScale(other);
    return _minor.compareTo(other._minor);
  }

  @override
  bool operator ==(Object other) {
    return other is DecimalAmount && other.scale == scale && other._minor == _minor;
  }

  @override
  int get hashCode => Object.hash(scale, _minor);

  @override
  String toString() {
    final negative = _minor.isNegative;
    final digits = _minor.abs().toString().padLeft(scale + 1, '0');
    if (scale == 0) return '${negative ? '-' : ''}$digits';
    final split = digits.length - scale;
    final whole = digits.substring(0, split);
    final fraction = digits.substring(split);
    return '${negative ? '-' : ''}$whole.$fraction';
  }

  void _requireSameScale(DecimalAmount other) {
    if (other.scale != scale) {
      throw FormatException('Scale mismatch');
    }
  }
}
