enum IndianMobileNumberIssue { empty, invalidLength, invalidPrefix, repeated }

class IndianMobileNumber {
  const IndianMobileNumber._();

  static String? normalize(String? rawValue) {
    var digits = rawValue?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (digits.isEmpty) return null;

    if (digits.length > 10 && digits.startsWith('0091')) {
      digits = digits.substring(4);
    } else if (digits.length > 10 && digits.startsWith('91')) {
      digits = digits.substring(2);
    }
    if (digits.length > 10 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    return digits;
  }

  static String inputDigits(String rawValue) {
    final normalized = normalize(rawValue) ?? '';
    if (normalized.length <= 10) return normalized;
    return normalized.substring(0, 10);
  }

  static IndianMobileNumberIssue? issue(String? rawValue) {
    final normalized = normalize(rawValue);
    if (normalized == null || normalized.isEmpty) {
      return IndianMobileNumberIssue.empty;
    }
    if (normalized.length != 10) {
      return IndianMobileNumberIssue.invalidLength;
    }
    if (!RegExp(r'^[6-9]').hasMatch(normalized)) {
      return IndianMobileNumberIssue.invalidPrefix;
    }
    if (RegExp(r'^(\d)\1{9}$').hasMatch(normalized)) {
      return IndianMobileNumberIssue.repeated;
    }
    return null;
  }

  static bool isValid(String? rawValue) => issue(rawValue) == null;

  static String message(IndianMobileNumberIssue issue) {
    return switch (issue) {
      IndianMobileNumberIssue.empty => 'Enter your mobile number',
      IndianMobileNumberIssue.invalidLength =>
        'Enter exactly 10 digits after +91',
      IndianMobileNumberIssue.invalidPrefix =>
        'Indian mobile numbers must start with 6, 7, 8, or 9',
      IndianMobileNumberIssue.repeated =>
        'Enter a real mobile number, not repeated digits',
    };
  }
}
