-- Stage 7-D3: Google Places gym discovery submissions.
-- Signed-in users submit a gym discovered via Google Places for review. Approved
-- submissions are promoted to public.gyms by an administrator/moderator (web
-- portal); this table holds the pending review queue.

create table public.gym_submissions (
  id uuid primary key default gen_random_uuid(),
  google_place_id text not null,
  name text not null,
  brand_name text,
  description text,
  street_address text,
  suburb text not null,
  state text not null,
  postcode text,
  latitude double precision not null,
  longitude double precision not null,
  submitted_by uuid references auth.users(id) on delete set null,
  status public.claim_status not null default 'submitted',
  reviewer_id uuid references auth.users(id) on delete set null,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint gym_submissions_place_id_length check (char_length(google_place_id) between 1 and 255),
  constraint gym_submissions_name_length check (char_length(name) between 1 and 100),
  constraint gym_submissions_brand_length check (brand_name is null or char_length(brand_name) <= 100),
  constraint gym_submissions_description_length check (description is null or char_length(description) <= 1000),
  constraint gym_submissions_address_length check (street_address is null or char_length(street_address) <= 500),
  constraint gym_submissions_review_note_length check (review_note is null or char_length(review_note) <= 1000),
  constraint gym_submissions_review_consistent check (
    (status = 'submitted' and reviewed_at is null)
    or (status in ('approved', 'rejected') and reviewed_at is not null and reviewer_id is not null)
  )
);

-- A given Google Place may only have one open submission at a time.
create unique index gym_submissions_one_open_per_place
  on public.gym_submissions (google_place_id)
  where status = 'submitted';

create index gym_submissions_status_idx
  on public.gym_submissions (status, created_at);

create trigger gym_submissions_set_updated_at
before update on public.gym_submissions
for each row execute function public.set_updated_at();

comment on table public.gym_submissions is
  'User-submitted gyms discovered via Google Places, awaiting review.';

alter table public.gym_submissions enable row level security;

-- Submitters can create and read their own submissions; moderators/admins review.
create policy gym_submissions_user_insert on public.gym_submissions
  for insert to authenticated
  with check (submitted_by = auth.uid() and status = 'submitted');

create policy gym_submissions_owner_read on public.gym_submissions
  for select to authenticated
  using (submitted_by = auth.uid() or public.is_admin_or_moderator());

create policy gym_submissions_moderator_review on public.gym_submissions
  for update to authenticated
  using (public.is_admin_or_moderator())
  with check (public.is_admin_or_moderator());

grant select, insert, update on public.gym_submissions to authenticated;
