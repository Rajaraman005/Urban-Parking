import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'notification engine migration encodes scale and reliability contracts',
    () {
      final sql = File(
        'supabase/migrations/202605100001_notification_engine.sql',
      ).readAsStringSync();

      expect(
        sql,
        contains('create table if not exists public.notification_events'),
      );
      expect(sql, contains('notification_events_idempotency_key_idx'));
      expect(
        sql,
        contains('create table if not exists public.notification_fanout_jobs'),
      );
      expect(sql, contains('notification_fanout_jobs_event_cursor_idx'));
      expect(
        sql,
        contains(
          'create table if not exists public.notification_delivery_jobs',
        ),
      );
      expect(
        sql,
        contains('create table if not exists public.notification_dead_letters'),
      );
      expect(
        sql,
        contains('create table if not exists public.notification_preferences'),
      );
      expect(
        sql,
        contains('create table if not exists public.notification_devices'),
      );
      expect(sql, contains('notification_devices_active_token_hash_idx'));
      expect(
        sql,
        contains('create table if not exists public.notification_templates'),
      );
      expect(sql, contains('notification_templates_one_active_idx'));
      expect(
        sql,
        contains(
          'create table if not exists public.notification_unread_counters',
        ),
      );
      expect(sql, contains('notification_counter_reconciliation_runs'));
      expect(sql, contains('partition by range (created_at)'));
      expect(sql, contains('notification_delivery_logs_202605'));
      expect(sql, contains('notification_audit_logs_202605'));
      expect(sql, contains('create_notification_event'));
      expect(sql, contains('p_shadow boolean default false'));
      expect(sql, contains('sync_notification_unread_counter'));
      expect(sql, contains('reconcile_notification_unread_counters'));
      expect(sql, contains('list_notifications'));
      expect(sql, contains('sync_notifications'));
      expect(sql, contains('mark_notifications_read'));
      expect(sql, contains('claim_notification_fanout_jobs'));
      expect(sql, contains('claim_notification_delivery_jobs'));
      expect(sql, contains('for update skip locked'));
      expect(sql, contains('notifications_event_recipient_dedupe_idx'));
      expect(sql, contains("status in ('pending', 'shadow'"));
      expect(sql, contains("array['in_app', 'realtime', 'push']"));
      expect(sql, contains('notification_events_no_client_access'));
      expect(sql, contains('notification_delivery_jobs_no_client_access'));
      expect(sql, contains('notification_unread_counters_select_own'));
    },
  );

  test(
    'legacy booking and messaging flows are cut over to live notification events',
    () {
      final baseSql = File(
        'supabase/migrations/202605100001_notification_engine.sql',
      ).readAsStringSync();
      final cutoverSql = File(
        'supabase/migrations/202605100002_notification_live_cutover.sql',
      ).readAsStringSync();

      expect(
        baseSql,
        contains(
          'create or replace function public.sync_conversation_last_message',
        ),
      );
      expect(cutoverSql, contains("p_event_type := 'message_received'"));
      expect(cutoverSql, contains("p_shadow := false"));
      expect(cutoverSql, isNot(contains('insert into public.notifications')));
      expect(
        cutoverSql,
        contains(
          'create or replace function public.enqueue_booking_notification',
        ),
      );
      expect(cutoverSql, contains("p_aggregate_type := 'booking'"));
      expect(cutoverSql, contains("p_template_key := 'booking.lifecycle'"));
    },
  );
}
