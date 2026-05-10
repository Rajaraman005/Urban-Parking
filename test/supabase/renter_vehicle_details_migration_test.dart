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

  test('profile vehicles migration adds multi-vehicle storage', () {
    final sql = File(
      'supabase/migrations/202605090001_profile_vehicles.sql',
    ).readAsStringSync();

    expect(sql, contains('create table if not exists public.profile_vehicles'));
    expect(sql, contains('unique (user_id, vehicle_registration)'));
    expect(sql, contains('profile_vehicles_one_primary_idx'));
    expect(sql, contains('profile_vehicles_select_own'));
    expect(sql, contains('insert into public.profile_vehicles'));
  });
}
