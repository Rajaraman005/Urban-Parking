import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('privacy and booking controls migration hardens core workflows', () {
    final sql = File(
      'supabase/migrations/202605080007_privacy_booking_controls.sql',
    ).readAsStringSync();

    expect(sql, contains('show_phone_number boolean not null default false'));
    expect(
      sql,
      contains("booking_approval_mode text not null default 'manual'"),
    );
    expect(sql, contains('update_profile_booking_controls'));
    expect(sql, contains('public_host_profile_payload'));
    expect(sql, contains("'hostPhone'"));
    expect(sql, contains('show_phone_number'));
    expect(sql, contains('then nullif'));
    expect(sql, contains('idempotency_key uuid not null'));
    expect(sql, contains('booking_request_hash'));
    expect(sql, contains("'vehicleKind', p_vehicle_kind"));
    expect(sql, contains('bookings_active_slot_no_overlap'));
    expect(sql, contains("where (status in ('pending', 'approved'))"));
    expect(sql, contains('create table if not exists public.booking_events'));
    expect(
      sql,
      contains('create table if not exists public.notification_outbox'),
    );
    expect(
      sql,
      contains('create table if not exists public.booking_expiry_job_runs'),
    );
    expect(
      sql,
      contains('expire_pending_bookings(p_batch_size integer default 500)'),
    );
    expect(sql, contains("'expiryBatchSaturated'"));
    expect(sql, contains("interval '7 days'"));
    expect(sql, contains('limit 10000'));
    expect(
      sql,
      contains('grant execute on function public.create_booking_request'),
    );
    expect(sql, contains('grant execute on function public.approve_booking'));
    expect(sql, contains('grant execute on function public.reject_booking'));
  });
}
