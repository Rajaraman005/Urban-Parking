enum IndianVehicleRegistrationIssue {
  empty,
  incomplete,
  invalidStateCode,
  invalidFormat,
}

class IndianVehicleRegistration {
  const IndianVehicleRegistration._();

  static final RegExp _standardPattern = RegExp(
    r'^([A-Z]{2})([0-9]{2})([A-Z]{1,3})([0-9]{1,4})$',
  );
  static final RegExp _bharatPattern = RegExp(
    r'^([0-9]{2})BH([0-9]{1,4})([A-Z]{1,2})$',
  );
  static final RegExp _statePrefixPattern = RegExp(r'^([A-Z]{2})[0-9]');

  static const Set<String> _stateCodes = {
    'AN',
    'AP',
    'AR',
    'AS',
    'BR',
    'CG',
    'CH',
    'DD',
    'DL',
    'DN',
    'GA',
    'GJ',
    'HP',
    'HR',
    'JH',
    'JK',
    'KA',
    'KL',
    'LA',
    'LD',
    'MH',
    'ML',
    'MN',
    'MP',
    'MZ',
    'NL',
    'OD',
    'OR',
    'PB',
    'PY',
    'RJ',
    'SK',
    'TN',
    'TR',
    'TS',
    'UA',
    'UK',
    'UP',
    'WB',
  };

  static String inputText(String rawValue) {
    final value = compact(rawValue);
    if (value.isEmpty) return '';

    final clamped = value.startsWith(RegExp(r'[0-9]'))
        ? _limit(value, 10)
        : _limit(value, 11);
    return _formatPartial(clamped);
  }

  static String compact(String? rawValue) {
    return (rawValue ?? '').trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
  }

  static String? normalize(String? rawValue) {
    final parsed = _parse(rawValue);
    return parsed?.compact;
  }

  static String formatForDisplay(String? rawValue) {
    final parsed = _parse(rawValue);
    if (parsed == null) return inputText(rawValue ?? '');
    return parsed.display;
  }

  static IndianVehicleRegistrationIssue? issue(String? rawValue) {
    final value = compact(rawValue);
    if (value.isEmpty) return IndianVehicleRegistrationIssue.empty;

    if (_parse(value) != null) return null;

    final statePrefix = _statePrefixPattern.firstMatch(value);
    if (statePrefix != null && !_stateCodes.contains(statePrefix.group(1))) {
      return IndianVehicleRegistrationIssue.invalidStateCode;
    }

    if (value.length < 8) return IndianVehicleRegistrationIssue.incomplete;
    return IndianVehicleRegistrationIssue.invalidFormat;
  }

  static String message(IndianVehicleRegistrationIssue issue) {
    return switch (issue) {
      IndianVehicleRegistrationIssue.empty => 'Enter your registration number',
      IndianVehicleRegistrationIssue.incomplete =>
        'Enter the full registration number, like TN 09 AB 1234',
      IndianVehicleRegistrationIssue.invalidStateCode =>
        'Use a valid Indian state or UT code, like TN, KA, MH, or DL',
      IndianVehicleRegistrationIssue.invalidFormat =>
        'Use a valid number like TN 09 AB 1234 or 25 BH 1234 AA',
    };
  }

  static String _formatPartial(String value) {
    if (value.startsWith(RegExp(r'[0-9]'))) {
      return _joinChunks(_fixedChunks(value, const [2, 2, 4, 2]));
    }

    final chunks = <String>[];
    var index = 0;
    if (value.isEmpty) return '';

    final stateEnd = value.length < 2 ? value.length : 2;
    chunks.add(value.substring(0, stateEnd));
    index = stateEnd;

    final authorityEnd = _takeWhile(
      value,
      index,
      maxCount: 2,
      matcher: _isDigit,
    );
    if (authorityEnd > index) {
      chunks.add(value.substring(index, authorityEnd));
      index = authorityEnd;
    }

    final seriesEnd = _takeWhile(value, index, maxCount: 3, matcher: _isLetter);
    if (seriesEnd > index) {
      chunks.add(value.substring(index, seriesEnd));
      index = seriesEnd;
    }

    final serialEnd = _takeWhile(value, index, maxCount: 4, matcher: _isDigit);
    if (serialEnd > index) {
      chunks.add(value.substring(index, serialEnd));
      index = serialEnd;
    }

    if (index < value.length) {
      chunks.add(value.substring(index));
    }
    return _joinChunks(chunks);
  }

  static Iterable<String> _fixedChunks(String value, List<int> sizes) sync* {
    var index = 0;
    for (final size in sizes) {
      if (index >= value.length) break;
      final end = (index + size).clamp(0, value.length);
      yield value.substring(index, end);
      index = end;
    }
  }

  static String _joinChunks(Iterable<String> chunks) {
    return chunks.where((chunk) => chunk.isNotEmpty).join(' ');
  }

  static int _takeWhile(
    String value,
    int start, {
    required bool Function(int codeUnit) matcher,
    required int maxCount,
  }) {
    var index = start;
    while (index < value.length &&
        index - start < maxCount &&
        matcher(value.codeUnitAt(index))) {
      index++;
    }
    return index;
  }

  static String _limit(String value, int maxLength) {
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;

  static bool _isLetter(int codeUnit) => codeUnit >= 65 && codeUnit <= 90;

  static _ParsedVehicleRegistration? _parse(String? rawValue) {
    final value = compact(rawValue);
    if (value.isEmpty) return null;

    final bharatMatch = _bharatPattern.firstMatch(value);
    if (bharatMatch != null) {
      final year = bharatMatch.group(1)!;
      final serial = bharatMatch.group(2)!.padLeft(4, '0');
      final suffix = bharatMatch.group(3)!;
      return _ParsedVehicleRegistration(
        compact: '${year}BH$serial$suffix',
        display: '$year BH $serial $suffix',
      );
    }

    final standardMatch = _standardPattern.firstMatch(value);
    if (standardMatch == null) return null;

    final state = standardMatch.group(1)!;
    if (!_stateCodes.contains(state)) return null;

    final authority = standardMatch.group(2)!;
    final series = standardMatch.group(3)!;
    final serial = standardMatch.group(4)!.padLeft(4, '0');
    return _ParsedVehicleRegistration(
      compact: '$state$authority$series$serial',
      display: '$state $authority $series $serial',
    );
  }
}

class _ParsedVehicleRegistration {
  const _ParsedVehicleRegistration({
    required this.compact,
    required this.display,
  });

  final String compact;
  final String display;
}
