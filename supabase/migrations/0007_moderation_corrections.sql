-- Corrections, removal evidence, duplicate proposals, reports and auditable actions.
create table public.route_corrections (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete restrict,
  submitted_by uuid references auth.users(id) on delete set null,
  issue_key text not null,
  proposed_value jsonb,
  explanation text,
  status public.correction_status not null default 'open',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint route_corrections_issue_length check (char_length(issue_key) between 1 and 80),
  constraint route_corrections_explanation_length check (explanation is null or char_length(explanation) <= 1000)
);

create unique index route_corrections_one_open_issue_per_user
  on public.route_corrections (route_id, submitted_by, issue_key)
  where status in ('open', 'under_review') and submitted_by is not null;

create table public.route_removal_reports (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete restrict,
  reported_by uuid references auth.users(id) on delete set null,
  observed_removed_at timestamptz,
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (route_id, reported_by)
);

create table public.route_merge_suggestions (
  id uuid primary key default gen_random_uuid(),
  source_route_id uuid not null references public.routes(id) on delete restrict,
  proposed_canonical_route_id uuid not null references public.routes(id) on delete restrict,
  suggested_by uuid references auth.users(id) on delete set null,
  reason text,
  status public.merge_status not null default 'proposed',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint route_merge_not_self check (source_route_id <> proposed_canonical_route_id),
  constraint route_merge_reason_length check (reason is null or char_length(reason) <= 1000),
  unique (source_route_id, proposed_canonical_route_id, suggested_by)
);

create table public.content_reports (
  id uuid primary key default gen_random_uuid(),
  target_type public.content_type not null,
  target_id uuid not null,
  category public.report_category not null,
  reporter_id uuid references auth.users(id) on delete set null,
  details text,
  is_severe boolean generated always as (
    category in ('nudity', 'harassment', 'violence', 'minor_privacy')
  ) stored,
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint content_reports_details_length check (details is null or char_length(details) <= 1000),
  unique (target_type, target_id, reporter_id)
);

create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  action_type public.moderation_action_type not null,
  target_type public.content_type,
  target_id uuid,
  target_user_id uuid references auth.users(id) on delete set null,
  performed_by uuid references auth.users(id) on delete set null,
  reason text not null,
  metadata jsonb not null default '{}'::jsonb,
  reversible boolean not null default true,
  reversed_by_action_id uuid references public.moderation_actions(id) on delete set null,
  restriction_ends_at timestamptz,
  created_at timestamptz not null default now(),
  constraint moderation_actions_reason_length check (char_length(reason) between 1 and 1000),
  constraint moderation_actions_target_present check (
    target_id is not null or target_user_id is not null
  )
);

create index route_corrections_queue_idx
  on public.route_corrections (status, route_id, created_at);
create index route_removal_queue_idx
  on public.route_removal_reports (status, route_id, created_at);
create index route_merge_queue_idx
  on public.route_merge_suggestions (status, created_at);
create index content_reports_target_status_idx
  on public.content_reports (target_type, target_id, status);
create index moderation_actions_target_idx
  on public.moderation_actions (target_type, target_id, created_at desc);

create trigger route_corrections_set_updated_at
before update on public.route_corrections
for each row execute function public.set_updated_at();
create trigger route_removal_reports_set_updated_at
before update on public.route_removal_reports
for each row execute function public.set_updated_at();
create trigger route_merge_suggestions_set_updated_at
before update on public.route_merge_suggestions
for each row execute function public.set_updated_at();
create trigger content_reports_set_updated_at
before update on public.content_reports
for each row execute function public.set_updated_at();

comment on table public.content_reports is
  'Reporter identity is private and available only to authorised moderation routines.';
