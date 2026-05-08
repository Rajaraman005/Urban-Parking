create index if not exists parking_listing_drafts_host_draft_updated_idx
on public.parking_listing_drafts (host_id, updated_at desc)
where status = 'draft';

create index if not exists parking_listing_draft_photos_linked_order_idx
on public.parking_listing_draft_photos (draft_id, sort_order asc, created_at asc)
where upload_status = 'linked';

notify pgrst, 'reload schema';
