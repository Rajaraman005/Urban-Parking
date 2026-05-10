create or replace function public.sync_conversation_last_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $sync_conversation_last_message$
declare
  v_recipient_ids jsonb;
begin
  if new.deleted_at is not null then
    return new;
  end if;

  update public.conversations
  set
    last_message_id = new.id,
    last_message_at = new.created_at,
    last_message_preview = public.messaging_message_preview(new.body, new.message_type)
  where id = new.conversation_id
    and (
      last_message_at is null
      or new.created_at >= last_message_at
    );

  select coalesce(jsonb_agg(cp.user_id::text), '[]'::jsonb)
  into v_recipient_ids
  from public.conversation_participants cp
  where cp.conversation_id = new.conversation_id
    and cp.user_id <> new.sender_id
    and cp.muted_until is distinct from 'infinity'::timestamptz;

  if jsonb_array_length(v_recipient_ids) > 0 then
    perform public.create_notification_event(
      p_event_type := 'message_received',
      p_aggregate_type := 'message',
      p_aggregate_id := new.id,
      p_actor_id := new.sender_id,
      p_recipient_selector := jsonb_build_object(
        'type', 'users',
        'userIds', v_recipient_ids
      ),
      p_category := 'message',
      p_priority := 'high',
      p_channels := array['in_app', 'realtime', 'push']::text[],
      p_template_key := 'message.received',
      p_template_version := 1,
      p_payload := jsonb_build_object(
        'title', 'New message',
        'body', public.messaging_message_preview(new.body, new.message_type),
        'conversationId', new.conversation_id,
        'messageId', new.id,
        'messageSeq', new.message_seq,
        'deeplink', '/messages/' || new.conversation_id::text
      ),
      p_idempotency_key := 'message:' || new.id::text || ':notification-event',
      p_dedupe_key := 'message:' || new.id::text,
      p_trace_id := 'message:' || new.id::text,
      p_shadow := false
    );
  end if;

  return new;
end;
$sync_conversation_last_message$;

create or replace function public.enqueue_booking_notification(
  p_booking public.bookings,
  p_recipient_id uuid,
  p_actor_id uuid,
  p_event_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $enqueue_booking_notification$
declare
  v_title text := case
    when p_event_type = 'host_booking_requested' then 'New booking request'
    when p_event_type = 'booking_auto_approved' then 'Booking approved'
    when p_event_type = 'booking_approved' then 'Booking approved'
    when p_event_type = 'booking_rejected' then 'Booking rejected'
    when p_event_type = 'booking_expired' then 'Booking expired'
    else 'Booking update'
  end;
begin
  insert into public.notification_outbox (
    recipient_id,
    actor_id,
    booking_id,
    event_type,
    payload
  )
  values (
    p_recipient_id,
    p_actor_id,
    p_booking.id,
    p_event_type,
    jsonb_build_object(
      'bookingId', p_booking.id,
      'spotId', p_booking.space_id,
      'status', p_booking.status,
      'startAt', p_booking.start_at,
      'endAt', p_booking.end_at
    )
  );

  perform public.create_notification_event(
    p_event_type := p_event_type,
    p_aggregate_type := 'booking',
    p_aggregate_id := p_booking.id,
    p_actor_id := p_actor_id,
    p_recipient_selector := jsonb_build_object(
      'type', 'users',
      'userIds', jsonb_build_array(p_recipient_id::text)
    ),
    p_category := 'booking',
    p_priority := case when p_event_type = 'host_booking_requested' then 'high' else 'normal' end,
    p_channels := array['in_app', 'realtime', 'push']::text[],
    p_template_key := 'booking.lifecycle',
    p_template_version := 1,
    p_payload := jsonb_build_object(
      'title', v_title,
      'body', 'Your parking booking status is ' || p_booking.status,
      'bookingId', p_booking.id,
      'spotId', p_booking.space_id,
      'status', p_booking.status,
      'startAt', p_booking.start_at,
      'endAt', p_booking.end_at,
      'deeplink', '/profile/booking-requests'
    ),
    p_idempotency_key := 'booking:' || p_booking.id::text || ':' || p_event_type || ':' || p_recipient_id::text,
    p_dedupe_key := 'booking:' || p_booking.id::text || ':' || p_event_type,
    p_trace_id := 'booking:' || p_booking.id::text,
    p_shadow := false
  );
end;
$enqueue_booking_notification$;
