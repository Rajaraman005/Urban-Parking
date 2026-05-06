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
}
