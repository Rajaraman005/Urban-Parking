import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/shared/validation/indian_mobile_number.dart';

void main() {
  test('normalizes Indian mobile paste formats', () {
    expect(IndianMobileNumber.normalize('+91 98765 43210'), '9876543210');
    expect(IndianMobileNumber.normalize('0091-98765-43210'), '9876543210');
    expect(IndianMobileNumber.normalize('09876543210'), '9876543210');
  });

  test('validates length prefix and repeated placeholders', () {
    expect(
      IndianMobileNumber.issue('987654321'),
      IndianMobileNumberIssue.invalidLength,
    );
    expect(
      IndianMobileNumber.issue('5876543210'),
      IndianMobileNumberIssue.invalidPrefix,
    );
    expect(
      IndianMobileNumber.issue('9999999999'),
      IndianMobileNumberIssue.repeated,
    );
    expect(IndianMobileNumber.issue('9876543210'), isNull);
  });
}
