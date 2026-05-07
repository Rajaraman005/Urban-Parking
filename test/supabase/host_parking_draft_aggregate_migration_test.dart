import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('host parking draft migration creates private aggregate contract', () {
    final sql = File(
      'supabase/migrations/202605070005_host_parking_draft_aggregate.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create table if not exists public.parking_listing_drafts'),
    );
    expect(
      sql,
      contains(
        'create table if not exists public.parking_listing_draft_photos',
      ),
    );
    expect(
      sql,
      contains('create table if not exists public.draft_mutation_log'),
    );
    expect(sql, contains('draft_mutation_log_service_role_only'));
    expect(sql, contains('revoke all on table public.draft_mutation_log'));
    expect(
      sql,
      isNot(
        contains(
          'alter publication supabase_realtime add table public.draft_mutation_log',
        ),
      ),
    );
  });

  test('host parking draft migration defines conflict and publish RPCs', () {
    final sql = File(
      'supabase/migrations/202605070005_host_parking_draft_aggregate.sql',
    ).readAsStringSync();

    expect(sql, contains('patch_host_parking_draft'));
    expect(sql, contains("'draft_conflict'"));
    expect(sql, contains("'auto_merged'"));
    expect(sql, contains('publish_host_parking_draft'));
    expect(sql, contains('for update'));
    expect(sql, contains('published_space_id'));
  });
}
