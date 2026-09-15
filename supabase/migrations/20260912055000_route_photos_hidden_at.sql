-- Align route_photos with the other moderated tables: hidden state carries a timestamp.
-- This also repairs the photo hide/restore paths that assumed the column.

alter table public.route_photos
  add column hidden_at timestamptz;

update public.route_photos
set hidden_at = updated_at
where moderation_status = 'temporarily_hidden'::public.moderation_status
  and hidden_at is null;

alter table public.route_photos
  add constraint route_photos_hidden_consistent check (
    (moderation_status = 'temporarily_hidden' and hidden_at is not null)
    or moderation_status <> 'temporarily_hidden'
  );

comment on column public.route_photos.hidden_at is
  'When moderation hid the photo; null while visible.';
