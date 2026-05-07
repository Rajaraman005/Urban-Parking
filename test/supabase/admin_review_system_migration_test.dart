import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin review migration creates dedicated auth and audit tables', () {
    final sql = File(
      'supabase/migrations/202605080001_admin_review_system.sql',
    ).readAsStringSync();

    expect(sql, contains('create table if not exists public.admin_users'));
    expect(sql, contains('create table if not exists public.admin_sessions'));
    expect(
      sql,
      contains('create table if not exists public.admin_login_attempts'),
    );
    expect(
      sql,
      contains(
        'create table if not exists public.parking_listing_review_events',
      ),
    );
    expect(sql, contains('prevent_review_event_mutation'));
    expect(sql, contains('admin_transition_parking_listing'));
  });

  test('admin review migration preserves public visibility gating', () {
    final sql = File(
      'supabase/migrations/202605080001_admin_review_system.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains(
        "check (status in ('draft', 'pending_review', 'active', 'rejected', 'suspended'))",
      ),
    );
    expect(sql, contains("where ps.status = 'active'"));
    expect(sql, contains('and ps.deleted_at is null'));
    expect(sql, contains('deleted_by_host_id'));
    expect(sql, contains('Soft-deletes user-owned listings'));
  });
}
