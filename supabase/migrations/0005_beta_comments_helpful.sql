-- External beta-link metadata, Helpful signals and flat comments.
create table public.beta_links (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete restrict,
  public_url text not null,
  normalised_url text not null,
  normalised_url_hash text not null,
  platform public.beta_platform not null,
  original_author_display_name text not null,
  original_post_url text not null,
  submitted_by uuid references auth.users(id) on delete set null,
  claimed_by_author boolean not null default false,
  author_removal_requested_at timestamptz,
  tags public.beta_tag[] not null default '{}',
  submitter_height_cm numeric(5,1),
  submitter_arm_span_cm numeric(5,1),
  helpful_count integer not null default 0,
  link_status public.beta_link_status not null default 'healthy',
  embed_capability public.embed_capability not null default 'source_platform_only',
  is_official_source boolean not null default false,
  moderation_status public.moderation_status not null default 'visible',
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint beta_links_public_https check (
    public_url ~* '^https://([a-z0-9-]+[.])+[a-z]{2,}(:[0-9]{1,5})?([/?#][^[:space:]]*)?$'
  ),
  constraint beta_links_original_https check (
    original_post_url ~* '^https://([a-z0-9-]+[.])+[a-z]{2,}(:[0-9]{1,5})?([/?#][^[:space:]]*)?$'
  ),
  constraint beta_links_normalised_https check (
    normalised_url ~* '^https://([a-z0-9-]+[.])+[a-z]{2,}(:[0-9]{1,5})?([/?#][^[:space:]]*)?$'
  ),
  constraint beta_links_hash_length check (char_length(normalised_url_hash) between 32 and 128),
  constraint beta_links_author_length check (char_length(original_author_display_name) between 1 and 120),
  constraint beta_links_height_range check (submitter_height_cm is null or submitter_height_cm between 100 and 250),
  constraint beta_links_arm_span_range check (submitter_arm_span_cm is null or submitter_arm_span_cm between 100 and 280),
  constraint beta_links_helpful_nonnegative check (helpful_count >= 0),
  constraint beta_links_hidden_consistent check (
    (moderation_status = 'temporarily_hidden' and hidden_at is not null)
    or moderation_status <> 'temporarily_hidden'
  )
);

create unique index beta_links_route_url_unique_active
  on public.beta_links (route_id, normalised_url_hash)
  where deleted_at is null;
create index beta_links_route_visible_idx
  on public.beta_links (route_id, helpful_count desc, created_at, id)
  where deleted_at is null and moderation_status = 'visible';
create index beta_links_submitter_idx
  on public.beta_links (submitted_by, created_at desc)
  where deleted_at is null;

create table public.beta_helpful_votes (
  beta_link_id uuid not null references public.beta_links(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (beta_link_id, user_id)
);

create table public.beta_comments (
  id uuid primary key default gen_random_uuid(),
  beta_link_id uuid not null references public.beta_links(id) on delete restrict,
  author_id uuid references auth.users(id) on delete set null,
  official_gym_id uuid references public.gyms(id) on delete set null,
  body text not null,
  moderation_status public.moderation_status not null default 'visible',
  hidden_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint beta_comments_body_length check (char_length(body) between 1 and 200),
  constraint beta_comments_hidden_consistent check (
    (moderation_status = 'temporarily_hidden' and hidden_at is not null)
    or moderation_status <> 'temporarily_hidden'
  )
);

create index beta_comments_beta_date_idx
  on public.beta_comments (beta_link_id, created_at)
  where deleted_at is null and moderation_status = 'visible';

create trigger beta_links_set_updated_at
before update on public.beta_links
for each row execute function public.set_updated_at();
create trigger beta_comments_set_updated_at
before update on public.beta_comments
for each row execute function public.set_updated_at();

comment on table public.beta_links is
  'Public external-link metadata only. No media bytes, upload state, download state, transcoding or cache fields.';
