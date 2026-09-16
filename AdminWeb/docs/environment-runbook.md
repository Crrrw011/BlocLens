# Operations Portal Environment Runbook

No credentials are embedded here. Values marked secret live only in the
hosting provider's environment editor (Vercel) or the Supabase dashboard.

## Local

| Concern | Value |
| --- | --- |
| Web | `npm run dev` in `AdminWeb/`, serves `http://127.0.0.1:3001` |
| Prod-like web | `npm run build && npm run start`, serves `http://127.0.0.1:3000` |
| Supabase API | `http://127.0.0.1:54321` |
| Supabase Studio | `http://127.0.0.1:54323` |
| Mailpit | `http://127.0.0.1:54324` |

`AdminWeb/.env.local` (gitignored) carries the local publishable key,
`ADMIN_ORIGIN=http://127.0.0.1:3000`, `SUPABASE_SECRET_KEY` (from
`supabase status`), and `CRON_SECRET` (any local random string).
`ADMIN_ORIGIN` must match the origin staff browsers use, or the staff
invitation route answers 403.

Reset with `supabase db reset`, then `supabase test db`. The seed
provides `fixture-admin@bloclens.invalid` and
`fixture-moderator@bloclens.invalid`, both password
`BlocLensLocalTest1!`. E2E suites dirty the database; always reset
before a gate run. Run Playwright with
`PLAYWRIGHT_OUTPUT_DIR=/tmp/<dir>` so artifact writes never trigger
the `:3001` dev watcher and corrupt the `:3000` build under test.

## Staging

- Supabase project `atmtqesdhxpgnrjedwsu`, test staff accounts only.
- Vercel Preview deployment of `AdminWeb/`.
- Environment variables: `NEXT_PUBLIC_SUPABASE_URL`,
  `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `ADMIN_ORIGIN` (the Preview
  URL), `SUPABASE_SECRET_KEY` (secret), `CRON_SECRET` (secret).
- Auth redirects: `<preview-url>/update-password`,
  `<preview-url>/accept-invite**`.
- Apply migrations in order; run `supabase test db` against a staging
  branch before promoting.

## Production

1. Create a new separate Supabase project (never reuse Staging).
2. Set the same five environment variables with production values.
3. Configure Auth redirects for the production origin only.
4. Apply the full migration sequence; review database advisors.
5. Bootstrap the owner outside the portal, in order:
   1. Create the owner Auth user (dashboard or Auth Admin API).
   2. Insert the `admin` row into `public.app_user_roles`.
   3. Insert the `can_manage_administrators = true` row into
      `public.staff_capabilities` with `granted_by` pointing at itself.
6. Deploy Vercel Production; verify the smoke/role flows; record the
   deployment URL in `final-acceptance.md`.
7. Never run Production deployment until the user explicitly authorises it.

## Rollback boundaries

- Web rollbacks are Vercel instant rollbacks (stateless frontend).
- Database migrations are append-only; a bad migration is repaired by a
  follow-up migration, never by editing history.
- Invitation, penalty, merge, deletion, and claim actions are
  idempotent by key and audited; replaying no-ops instead of duplicating.
