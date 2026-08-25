-- Attempt-gated community grades and private, idempotent Logbook entries.
create table public.logbook_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  route_id uuid not null references public.routes(id) on delete restrict,
  status public.logbook_status not null,
  climbed_at timestamptz not null,
  attempts integer,
  private_note text,
  predicted_v_grade smallint,
  client_created_at timestamptz not null,
  client_idempotency_key uuid not null,
  merged_into_entry_id uuid references public.logbook_entries(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint logbook_attempts_range check (attempts is null or attempts between 0 and 999),
  constraint logbook_note_length check (private_note is null or char_length(private_note) <= 4000),
  constraint logbook_grade_range check (predicted_v_grade is null or predicted_v_grade between -1 and 17),
  unique (user_id, route_id),
  unique (user_id, client_idempotency_key)
);

create index logbook_user_status_date_idx
  on public.logbook_entries (user_id, status, climbed_at desc)
  where deleted_at is null;
create index logbook_route_idx
  on public.logbook_entries (route_id)
  where deleted_at is null;

create table public.route_grade_votes (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  v_grade smallint not null,
  is_valid boolean not null default true,
  superseded_at timestamptz,
  superseded_by_route_id uuid references public.routes(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint route_grade_votes_grade_range check (v_grade between -1 and 17),
  unique (route_id, user_id)
);

create index route_grade_votes_route_valid_idx
  on public.route_grade_votes (route_id, v_grade)
  where is_valid;

create or replace function public.has_attempted_route(requested_route_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.logbook_entries entry
    where entry.user_id = auth.uid()
      and entry.route_id = requested_route_id
      and entry.status in (
        'projecting'::public.logbook_status,
        'sent'::public.logbook_status,
        'flash'::public.logbook_status
      )
      and entry.deleted_at is null
  );
$$;

revoke all on function public.has_attempted_route(uuid) from public;
grant execute on function public.has_attempted_route(uuid) to authenticated;

create trigger logbook_entries_set_updated_at
before update on public.logbook_entries
for each row execute function public.set_updated_at();
create trigger route_grade_votes_set_updated_at
before update on public.route_grade_votes
for each row execute function public.set_updated_at();

comment on column public.logbook_entries.private_note is
  'Owner-only private content. It is never exposed by a public view or routine moderation query.';
comment on column public.logbook_entries.client_idempotency_key is
  'Stable client key for safe repeated synchronisation; queued is a client-only state.';
