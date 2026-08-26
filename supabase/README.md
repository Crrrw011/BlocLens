# BlocLens Supabase Schema

## Scope

This directory defines the future BlocLens PostgreSQL boundary. Stage 6A does not connect a remote Supabase project, add the Supabase Swift SDK, create Storage buckets or change the app's default in-memory repositories. No URL, anon key, service-role key or other credential belongs in this repository.

The SQL targets a future disposable local Supabase environment first. Production migrations never insert development fixtures.

## Migration order

Apply files in lexical order:

1. `0001_foundations.sql` — extensions, constrained enums and the shared `updated_at` trigger.
2. `0002_profiles_roles.sql` — private application profiles and secure administrator or moderator roles.
3. `0003_gyms_wall_zones.sql` — gyms, facilities, official memberships and named wall zones.
4. `0004_routes_resets_photos.sql` — climbing routes, reset evidence and route-photo metadata.
5. `0005_beta_comments_helpful.sql` — external beta-link metadata, Helpful votes and flat comments.
6. `0006_grade_votes_logbook.sql` — private Logbook entries and attempt-gated grade votes.
7. `0007_moderation_corrections.sql` — corrections, removal reports, duplicate suggestions and moderation audit records.
8. `0008_relationships_notifications_feedback_claims.sql` — favourites, follows, private blocks, preferences, outbox, gym claims and feedback.
9. `0009_rls_policies.sql` — RLS, policies and least-privilege grants for every client-facing business table.
10. `0010_functions_triggers_views.sql` — aggregate maintenance, moderation thresholds, safe RPCs, transactional merge and security-invoker views.
11. `0011_harden_beta_access_and_search.sql` — authenticated beta metadata access, guest-safe counts and indexed local search.
12. `0012_harden_cloud_function_and_view_privileges.sql` — least-privilege RPC and view grants, safe beta URL normalisation and extension schema hardening.

The sequence is dependency-sensitive. Do not reorder or combine it simply to reduce file count.

## Future local execution

Supabase CLI is not required for this stage and must not be installed merely to validate these files. When a compatible local Supabase toolchain is deliberately configured later:

```sh
supabase start
supabase db reset
```

The reset command should apply `migrations/` in order and then `seed.sql`. Run it only against a disposable local development database. Then execute `tests/schema_contract.sql` with the local PostgreSQL client or the test command selected for that environment.

The seed writes three fixed mock rows to `auth.users` so authenticated relationship fixtures can satisfy foreign keys. Those identities use `.invalid` email addresses and no usable password. Because Supabase may evolve the internal `auth.users` columns, review the local version before executing the seed. Never apply `seed.sql` to production.

To clear local development data, reset the disposable local database instead of deleting individual historical rows. Do not run reset commands against a linked remote project.

## Current validation

Run the repository-owned static contract check without a database:

```sh
ruby supabase/tests/static_schema_checks.rb
```

It validates migration ordering and termination, dollar-quote balance, expected tables, RLS and policy coverage, safe function search paths, explicit client RPC and view grants, fixture counts, development-only hosts and the absence of video tables or credential-like values. Static validation complements, but does not replace, the disposable local PostgreSQL reset and pgTAP contract suite.

## Development and production separation

- Migrations contain schema and policy only.
- `seed.sql` contains deterministic development fixtures only.
- Fixed UUIDs align with the mapping documented by `RemoteSeedIdentifiers` without replacing the existing readable in-memory identifiers.
- Example beta records use `https://example.com` and fictitious author names.
- Production import, Google Places synchronisation and real users are outside this stage.

## Secrets and configuration

Local environment files are ignored by Git. Keep project URLs and public client keys in a future local configuration mechanism, and keep service-role credentials exclusively in secure server or administrator infrastructure. The iPhone app must never receive a service-role key. Do not commit CLI temporary state or local branch metadata.

## Storage boundary

No bucket is created here. Future planning permits image-only metadata for `avatars`, `gym-photos`, `route-photos` and `feedback-attachments`. Route photos store a Storage path and dimensions, not image bytes. BlocLens has no video table, video bucket or video transfer path. Beta remains public external-link metadata only.
