-- Commercial bouldering gyms, facilities, official memberships and named wall zones.
create table public.gyms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  brand_name text,
  slug citext not null,
  description text,
  street_address text,
  suburb text not null,
  state text not null,
  postcode text,
  country_code text not null default 'AU',
  latitude double precision not null,
  longitude double precision not null,
  phone text,
  website text,
  opening_hours jsonb,
  google_place_id text,
  google_attribution_required boolean not null default false,
  is_claimed boolean not null default false,
  is_verified boolean not null default false,
  data_source public.gym_data_source not null default 'community',
  last_source_sync_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint gyms_name_length check (char_length(name) between 1 and 120),
  constraint gyms_brand_length check (brand_name is null or char_length(brand_name) <= 120),
  constraint gyms_slug_length check (char_length(slug::text) between 1 and 100),
  constraint gyms_description_length check (description is null or char_length(description) <= 2000),
  constraint gyms_country_au check (country_code = 'AU'),
  constraint gyms_latitude_range check (latitude between -44 and -10),
  constraint gyms_longitude_range check (longitude between 112 and 154),
  constraint gyms_postcode_format check (postcode is null or postcode ~ '^[0-9]{4}$'),
  constraint gyms_website_https check (website is null or website ~* '^https://')
);

create unique index gyms_slug_unique_active
  on public.gyms (lower(slug::text))
  where deleted_at is null;
create index gyms_state_suburb_idx on public.gyms (state, suburb) where deleted_at is null;
create index gyms_map_bounds_idx on public.gyms (latitude, longitude) where deleted_at is null;
create index gyms_name_search_idx on public.gyms (lower(name)) where deleted_at is null;

alter table public.profiles
  add constraint profiles_favourite_gym_fk
  foreign key (favourite_gym_id) references public.gyms(id) on delete set null;

create table public.gym_facilities (
  gym_id uuid not null references public.gyms(id) on delete cascade,
  facility public.facility_code not null,
  is_available boolean not null default true,
  source public.gym_data_source not null default 'community',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (gym_id, facility)
);

create table public.gym_memberships (
  gym_id uuid not null references public.gyms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.gym_membership_role not null default 'verified_representative',
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  primary key (gym_id, user_id, role)
);

create or replace function public.is_gym_official(requested_gym_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.gym_memberships membership
    where membership.gym_id = requested_gym_id
      and membership.user_id = auth.uid()
      and membership.role = 'verified_representative'::public.gym_membership_role
      and membership.revoked_at is null
  );
$$;

revoke all on function public.is_gym_official(uuid) from public;
grant execute on function public.is_gym_official(uuid) to authenticated;

create table public.wall_zones (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references public.gyms(id) on delete restrict,
  name text not null,
  description text,
  location_description text,
  wall_type public.wall_type not null,
  display_order integer not null default 0,
  availability public.wall_zone_availability not null default 'active',
  last_reset_date timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint wall_zones_name_length check (char_length(name) between 1 and 100),
  constraint wall_zones_description_length check (description is null or char_length(description) <= 1000),
  constraint wall_zones_location_length check (location_description is null or char_length(location_description) <= 240),
  constraint wall_zones_order_nonnegative check (display_order >= 0),
  constraint wall_zones_archive_consistent check (
    (availability = 'archived' and archived_at is not null)
    or availability <> 'archived'
  ),
  unique (id, gym_id)
);

create unique index wall_zones_name_unique_active
  on public.wall_zones (gym_id, lower(name))
  where archived_at is null;
create index wall_zones_gym_order_idx
  on public.wall_zones (gym_id, display_order)
  where archived_at is null;

create trigger gyms_set_updated_at
before update on public.gyms
for each row execute function public.set_updated_at();
create trigger gym_facilities_set_updated_at
before update on public.gym_facilities
for each row execute function public.set_updated_at();
create trigger wall_zones_set_updated_at
before update on public.wall_zones
for each row execute function public.set_updated_at();

comment on table public.wall_zones is
  'Named list-based wall zones only. No 2D coordinates, polygons, hotspots or indoor geometry.';
