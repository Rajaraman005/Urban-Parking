import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'renter vehicle details migration adds setup step and profile columns',
    () {
      final sql = File(
        'supabase/migrations/202605080005_renter_vehicle_details.sql',
      ).readAsStringSync();

      expect(sql, contains('vehicle_details'));
      expect(sql, contains('vehicle_type'));
      expect(sql, contains('vehicle_registration'));
      expect(sql, contains('profiles_vehicle_type_check'));
      expect(sql, contains('profiles_vehicle_registration_format_check'));
      expect(sql, contains('grant update'));
    },
  );
}
