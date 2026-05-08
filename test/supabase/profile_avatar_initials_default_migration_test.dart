import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile avatar migration stops seeding Google photos by default', () {
    final sql = File(
      'supabase/migrations/202605080006_profile_avatar_initials_default.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create or replace function public.ensure_user_profile'),
    );
    expect(sql, isNot(contains('v_avatar_url')));
    expect(sql, contains('avatar_public_id is null'));
    expect(sql, contains('googleusercontent'));
    expect(sql, contains('provider avatars stay opt-in'));
  });
}
