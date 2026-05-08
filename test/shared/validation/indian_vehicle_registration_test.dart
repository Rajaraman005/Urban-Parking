import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/shared/validation/indian_vehicle_registration.dart';

void main() {
  test('formats registration spacing while typing', () {
    expect(IndianVehicleRegistration.inputText('t'), 'T');
    expect(IndianVehicleRegistration.inputText('tn'), 'TN');
    expect(IndianVehicleRegistration.inputText('tn0'), 'TN 0');
    expect(IndianVehicleRegistration.inputText('tn09'), 'TN 09');
    expect(IndianVehicleRegistration.inputText('tn09a'), 'TN 09 A');
    expect(IndianVehicleRegistration.inputText('tn09ab1234'), 'TN 09 AB 1234');
    expect(IndianVehicleRegistration.inputText('25bh1234aa'), '25 BH 1234 AA');
  });

  test('normalizes standard Indian plates and fancy serials', () {
    expect(IndianVehicleRegistration.normalize('tn 09 ab 1234'), 'TN09AB1234');
    expect(IndianVehicleRegistration.normalize('tn09ab7'), 'TN09AB0007');
    expect(
      IndianVehicleRegistration.formatForDisplay('tn09ab7'),
      'TN 09 AB 0007',
    );
  });

  test('normalizes Bharat series plates', () {
    expect(IndianVehicleRegistration.normalize('25 bh 1234 aa'), '25BH1234AA');
    expect(IndianVehicleRegistration.normalize('25-bh-7-a'), '25BH0007A');
    expect(
      IndianVehicleRegistration.formatForDisplay('25bh7a'),
      '25 BH 0007 A',
    );
  });

  test('classifies invalid registration numbers', () {
    expect(
      IndianVehicleRegistration.issue(''),
      IndianVehicleRegistrationIssue.empty,
    );
    expect(
      IndianVehicleRegistration.issue('TN'),
      IndianVehicleRegistrationIssue.incomplete,
    );
    expect(
      IndianVehicleRegistration.issue('ZZ09AB1234'),
      IndianVehicleRegistrationIssue.invalidStateCode,
    );
    expect(
      IndianVehicleRegistration.issue('TNAB1234'),
      IndianVehicleRegistrationIssue.invalidFormat,
    );
    expect(IndianVehicleRegistration.issue('TN09AB0001'), isNull);
  });
}
