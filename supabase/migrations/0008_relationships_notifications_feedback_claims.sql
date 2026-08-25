-- Personal relationships, notification preferences, feedback and gym claims.
create table public.favourite_gyms (
  user_id uuid not null references auth.users(id) on delete cascade,
  gym_id uuid not null references public.gyms(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, gym_id)
);

create table public.user_follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  followed_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  constraint user_follows_not_self check (follower_id <> followed_id)
);

create table public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);

create table public.notification_preferences (
  user_id uuid not null references auth.users(id) on delete cascade,
  category public.notification_category not null,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, category)
);

create table public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  category public.notification_category not null,
  source_record_id uuid,
  payload jsonb not null default '{}'::jsonb,
  available_at timestamptz not null default now(),
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint notification_outbox_payload_size check (octet_length(payload::text) <= 16000)
);

create table public.gym_claims (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms(id) on delete restrict,
  applicant_id uuid references auth.users(id) on delete set null,
  domain_email citext not null,
  verification_method public.verification_method not null,
  status public.claim_status not null default 'submitted',
  reviewer_id uuid references auth.users(id) on delete set null,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint gym_claims_email_length check (char_length(domain_email::text) between 3 and 254),
  constraint gym_claims_email_format check (domain_email::text ~* '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'),
  constraint gym_claims_review_note_length check (review_note is null or char_length(review_note) <= 1000),
  constraint gym_claims_review_consistent check (
    (status = 'submitted' and reviewed_at is null)
    or (status in ('approved', 'rejected') and reviewed_at is not null and reviewer_id is not null)
  )
);

create unique index gym_claims_one_active_per_applicant
  on public.gym_claims (gym_id, applicant_id)
  where status = 'submitted' and applicant_id is not null;
create index gym_memberships_user_idx
  on public.gym_memberships (user_id, gym_id)
  where revoked_at is null;

create table public.app_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  category public.feedback_category not null,
  message text not null,
  screenshot_storage_path text,
  current_page_id text,
  app_version text,
  os_version text,
  device_model text,
  status public.feedback_status not null default 'received',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint app_feedback_message_length check (char_length(message) between 1 and 4000),
  constraint app_feedback_screenshot_path_length check (screenshot_storage_path is null or char_length(screenshot_storage_path) <= 512),
  constraint app_feedback_page_id_length check (current_page_id is null or char_length(current_page_id) <= 40),
  constraint app_feedback_metadata_length check (
    (app_version is null or char_length(app_version) <= 40)
    and (os_version is null or char_length(os_version) <= 80)
    and (device_model is null or char_length(device_model) <= 120)
  )
);

create index favourite_gyms_user_idx on public.favourite_gyms (user_id, created_at desc);
create index user_follows_followed_idx on public.user_follows (followed_id, follower_id);
create index notification_preferences_user_idx on public.notification_preferences (user_id);
create index notification_outbox_pending_idx
  on public.notification_outbox (available_at, category)
  where processed_at is null;
create index gym_claims_status_idx on public.gym_claims (status, created_at);

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();
create trigger gym_claims_set_updated_at
before update on public.gym_claims
for each row execute function public.set_updated_at();
create trigger app_feedback_set_updated_at
before update on public.app_feedback
for each row execute function public.set_updated_at();

comment on table public.user_blocks is
  'Private relationship. A blocked user must never be able to discover who blocked them.';
comment on table public.notification_outbox is
  'Future server-side event seam only. No APNs device tokens are stored in Stage 6A.';
