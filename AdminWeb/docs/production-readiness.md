# Production Readiness

## Security posture

- Browser bundles receive only `NEXT_PUBLIC_SUPABASE_URL` and
  `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`. Verified by scanning
  `AdminWeb/.next/static` for `SUPABASE_SECRET`, `CRON_SECRET`, and
  `SERVICE_ROLE` after every production build (Gate 7 step).
- `SUPABASE_SECRET_KEY` and `CRON_SECRET` are server-only env vars.
- Security headers ship from `next.config.ts`: CSP (Next-compatible,
  see below), frame denial, nosniff, no-referrer, and a closed
  permissions policy. Authenticated views and credential flows add
  `Cache-Control: no-store` in middleware.
- CSP ships `script-src 'self' 'unsafe-inline'` because Next.js emits
  runtime inline scripts. Removing `'unsafe-inline'` requires per-request
  nonces plumbed through middleware and the root layout; tracked as a
  hardening follow-up, not a release blocker.
- The audit export exposes nine explicit columns; raw IPs are not among
  them and cannot become so without a migration plus review.
- The IP-retention cron accepts no parameters (90-day window in SQL),
  requires `Bearer $CRON_SECRET`, and its routine is granted to
  `service_role` only.

## Data protection

- Private Logbook entries, notes, emails, and invitation tokens never
  enter projections, exports, fixtures, or screenshots. pgTAP asserts
  this per feature.
- Audit IPs older than 90 days are replaced by keyed digests via the
  daily cron; repeated runs no-op.
- Penalties lift automatically at read time when `ends_at` passes.

## Operational limits

- List pages cap at 100 rows per request with cursor pagination.
- Audit export caps at 90 days and 10,000 rows per download.
- Storage cleanup precedes database deletion; partial file failures
  abort the deletion instead of misreporting success.

## Pre-release checklist

1. `supabase db reset && supabase test db` — all suites pass.
2. `npm ci && npm run lint && npm run typecheck && npm test -- --run`.
3. `npm run build && npm run test:e2e` against a clean database.
4. Database advisors clean; dependency audit clean.
5. Browser bundle secret scan clean.
6. Keyboard-only, reduced-motion, and 1440/1024/768/390 visual passes.
7. Vercel Preview against Staging re-verified; evidence recorded.
