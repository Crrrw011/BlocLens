-- Route lifecycle, reset evidence and route-photo metadata.
create table public.routes (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null,
  wall_zone_id uuid not null,
  colour text,
  label text,
  gym_grade smallint,
  lifecycle public.route_lifecycle not null default 'active',
  set_date timestamptz,
  estimated_archive_date timestamptz,
  is_archive_date_estimated boolean not null default false,
  archived_at timestamptz,
  archived_reason text,
  canonical_route_id uuid references public.routes(id) on delete restrict,
  created_by uuid references auth.users(id) on delete set null,
  is_official_source boolean not null default false,
  moderation_status public.moderation_status not null default 'visible',
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint routes_zone_gym_fk foreign key (wall_zone_id, gym_id)
    references public.wall_zones(id, gym_id) on delete restrict,
  constraint routes_identity_required check (
    nullif(btrim(colour), '') is not null or nullif(btrim(label), '') is not null
  ),
  constraint routes_colour_length check (colour is null or char_length(colour) <= 80),
  constraint routes_label_length check (label is null or char_length(label) <= 120),
  constraint routes_grade_range check (gym_grade is null or gym_grade between -1 and 17),
  constraint routes_archive_estimate_consistent check (
    not is_archive_date_estimated or estimated_archive_date is not null
  ),
  constraint routes_archived_consistent check (
    (lifecycle = 'archived' and archived_at is not null)
    or lifecycle <> 'archived'
  ),
  constraint routes_hidden_consistent check (
    (moderation_status = 'temporarily_hidden' and hidden_at is not null)
    or moderation_status <> 'temporarily_hidden'
  ),
  constraint routes_canonical_not_self check (canonical_route_id is null or canonical_route_id <> id)
);

create index routes_gym_lifecycle_idx
  on public.routes (gym_id, lifecycle, set_date desc)
  where deleted_at is null;
create index routes_zone_lifecycle_idx
  on public.routes (wall_zone_id, lifecycle, set_date desc)
  where deleted_at is null;
create index routes_archived_idx
  on public.routes (archived_at desc)
  where lifecycle = 'archived' and deleted_at is null;
create index routes_grade_idx on public.routes (gym_grade) where deleted_at is null;
create index routes_colour_idx on public.routes (lower(colour)) where deleted_at is null;
create index routes_label_idx on public.routes (lower(label)) where deleted_at is null;

create table public.gym_reset_patterns (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms(id) on delete cascade,
  wall_zone_id uuid references public.wall_zones(id) on delete cascade,
  cycle_days integer not null,
  is_official boolean not null default false,
  confidence numeric(4,3),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint reset_patterns_cycle_range check (cycle_days between 1 and 365),
  constraint reset_patterns_confidence_range check (confidence is null or confidence between 0 and 1)
);

create table public.reset_events (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms(id) on delete restrict,
  wall_zone_id uuid references public.wall_zones(id) on delete restrict,
  reset_date timestamptz not null,
  source public.reset_source not null,
  state public.reset_state not null default 'pending',
  confirmation_count integer not null default 0,
  is_estimated boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  is_official boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint reset_events_confirmation_nonnegative check (confirmation_count >= 0),
  constraint reset_events_source_consistent check (
    (is_official and source = 'official' and state = 'confirmed' and not is_estimated)
    or (not is_official)
  ),
  constraint reset_events_estimate_consistent check (
    (is_estimated and source = 'estimated' and state = 'estimated')
    or not is_estimated
  )
);

create table public.reset_confirmations (
  reset_event_id uuid not null references public.reset_events(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  confirmed_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (reset_event_id, user_id)
);

create index reset_events_gym_date_idx
  on public.reset_events (gym_id, reset_date desc)
  where deleted_at is null;
create index reset_events_zone_date_idx
  on public.reset_events (wall_zone_id, reset_date desc)
  where deleted_at is null;

create table public.route_photos (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete restrict,
  storage_path text not null,
  uploaded_by uuid references auth.users(id) on delete set null,
  is_official_source boolean not null default false,
  helpful_count integer not null default 0,
  moderation_status public.moderation_status not null default 'visible',
  width integer,
  height integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint route_photos_path_length check (char_length(storage_path) between 1 and 512),
  constraint route_photos_dimensions check (
    (width is null and height is null)
    or (width between 1 and 20000 and height between 1 and 20000)
  ),
  constraint route_photos_helpful_nonnegative check (helpful_count >= 0)
);

create table public.route_photo_helpful_votes (
  photo_id uuid not null references public.route_photos(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (photo_id, user_id)
);

create index route_photos_route_priority_idx
  on public.route_photos (route_id, is_official_source desc, helpful_count desc, created_at)
  where deleted_at is null and moderation_status = 'visible';

create trigger routes_set_updated_at
before update on public.routes
for each row execute function public.set_updated_at();
create trigger gym_reset_patterns_set_updated_at
before update on public.gym_reset_patterns
for each row execute function public.set_updated_at();
create trigger reset_events_set_updated_at
before update on public.reset_events
for each row execute function public.set_updated_at();
create trigger route_photos_set_updated_at
before update on public.route_photos
for each row execute function public.set_updated_at();

comment on table public.route_photos is
  'Photo storage paths and metadata only. Image bytes are stored outside PostgreSQL.';
