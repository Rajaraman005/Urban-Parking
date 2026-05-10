import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('messaging migration encodes consistency and security gates', () {
    final sql = File(
      'supabase/migrations/202605090002_messaging_system.sql',
    ).readAsStringSync();

    expect(sql, contains('create table if not exists public.conversations'));
    expect(
      sql,
      contains('create table if not exists public.conversation_participants'),
    );
    expect(sql, contains('last_read_message_seq bigint not null default 0'));
    expect(sql, isNot(contains('unread_count')));
    expect(sql, contains('messages_conversation_seq_visible_idx'));
    expect(sql, contains('where deleted_at is null'));
    expect(sql, contains("|| least(p_user_a::text, p_user_b::text)"));
    expect(sql, contains('on conflict (conversation_key) do update'));
    expect(sql, contains('set updated_at = public.conversations.updated_at'));
    expect(
      sql,
      isNot(
        matches(
          RegExp(
            r"from public\.parking_spaces\s+where id = p_property_id\s+and status = 'active'\s+and deleted_at is null",
          ),
        ),
      ),
    );
    expect(sql, contains('for update'));
    expect(sql, contains('last_read_message_seq = greatest'));
    expect(sql, contains('unique (sender_id, client_message_id)'));
    expect(sql, contains("'reserved',"));
    expect(sql, contains("'scanning',"));
    expect(sql, contains("'scan_failed_retryable',"));
    expect(sql, contains("now() + interval '30 minutes'"));
    expect(sql, contains('expire_stale_message_attachment_slots'));
    expect(sql, contains('message_attachments_storage_select_available'));
    expect(sql, contains('EXPLAIN ANALYZE'));
    expect(sql, contains('supabase_realtime add table public.messages'));
  });
}
