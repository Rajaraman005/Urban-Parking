import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parking listing realtime migration exposes safe revision contract', () {
    final sql = File(
      'supabase/migrations/202605060003_parking_listing_revisions_and_owner_edits.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create table if not exists public.parking_listing_revisions'),
    );
    expect(sql, contains('parking_listing_revisions_public_select'));
    expect(
      sql,
      contains(
        'alter publication supabase_realtime add table public.parking_listing_revisions',
      ),
    );
    expect(
      sql,
      contains(
        'create or replace function public.update_owned_parking_space_address',
      ),
    );
    expect(
      sql,
      contains(
        'create or replace function public.update_owned_parking_space_pricing',
      ),
    );
    expect(sql, contains("'listingRevision'"));
    expect(sql, contains("'isHostedByCurrentUser'"));
  });

  test('pricing weekend migration keeps old and new RPC signatures usable', () {
    final sql = File(
      'supabase/migrations/202605070001_parking_pricing_skip_weekends_rpc.sql',
    ).readAsStringSync();

    expect(sql, contains('p_skip_weekends boolean'));
    expect(sql, contains('skip_weekends = coalesce(p_skip_weekends, false)'));
    expect(
      sql,
      contains(
        'create or replace function public.update_owned_parking_space_pricing',
      ),
    );
    expect(sql, contains('p_daily_end_minute integer\n)'));
    expect(
      sql,
      contains(
        'select public.update_owned_parking_space_pricing(\n'
        '    p_space_id,\n'
        '    p_expected_version,\n'
        '    p_hourly_price,\n'
        '    p_slots_count,\n'
        '    p_available_from_date,\n'
        '    p_available_to_date,\n'
        '    p_daily_start_minute,\n'
        '    p_daily_end_minute,\n'
        '    false',
      ),
    );
  });

  test('pricing repair migration restores schema before RPC execution', () {
    final sql = File(
      'supabase/migrations/202605070002_pricing_schema_rpc_repair.sql',
    ).readAsStringSync();

    expect(sql, contains('add column if not exists available_from_date date'));
    expect(sql, contains('add column if not exists available_to_date date'));
    expect(
      sql,
      contains('add column if not exists daily_start_minute integer'),
    );
    expect(sql, contains('add column if not exists daily_end_minute integer'));
    expect(sql, contains('add column if not exists skip_weekends boolean'));
    expect(sql, contains('parking_spaces_available_date_range_check'));
    expect(sql, contains('parking_spaces_daily_minutes_check'));
    expect(sql, contains('p_skip_weekends boolean'));
    expect(sql, contains("'skipWeekends', t.skip_weekends"));
    expect(sql, contains("notify pgrst, 'reload schema'"));
  });

  test('public parking detail migration exposes host description safely', () {
    final sql = File(
      'supabase/migrations/202605070003_public_parking_spot_description.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains("nullif(btrim(to_jsonb(ps)->>'access_instructions'), '')"),
    );
    expect(sql, contains("'description', t.description"));
    expect(sql, contains('renter-facing description'));
    expect(sql, contains("notify pgrst, 'reload schema'"));
  });

  test('description length migration enforces renter copy bounds', () {
    final sql = File(
      'supabase/migrations/202605070004_parking_space_description_length.sql',
    ).readAsStringSync();

    expect(sql, contains('before insert or update of access_instructions'));
    expect(sql, contains('char_length(new.access_instructions) < 50'));
    expect(sql, contains('char_length(new.access_instructions) > 200'));
    expect(sql, contains('parking_spaces_description_length_check'));
    expect(sql, contains("notify pgrst, 'reload schema'"));
  });
}
