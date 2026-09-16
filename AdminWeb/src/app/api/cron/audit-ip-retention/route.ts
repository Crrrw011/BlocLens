import { createClient } from "@supabase/supabase-js";

import { env } from "@/lib/env";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Daily IP retention for audit events (90-day window, enforced in SQL).
 * Vercel Cron calls this with `Authorization: Bearer $CRON_SECRET`.
 * The service key never leaves the server; the retention routine itself
 * is granted to service_role only.
 */
export async function GET(request: Request): Promise<Response> {
  const secret = process.env.CRON_SECRET;
  if (!secret) {
    return Response.json({ status: "misconfigured" }, { status: 500 });
  }
  const presented = request.headers.get("authorization");
  if (presented !== `Bearer ${secret}`) {
    return Response.json({ status: "denied" }, { status: 401 });
  }

  // Local Supabase exposes a publishable key plus a server secret; the
  // secret authenticates as service_role for this server-only call.
  const serviceKey =
    process.env.SUPABASE_SECRET_KEY ?? process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  if (!serviceKey) {
    return Response.json({ status: "misconfigured" }, { status: 500 });
  }
  const admin = createClient(env.NEXT_PUBLIC_SUPABASE_URL, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
  // The 90-day cutoff lives inside the routine; callers pass no parameters.
  const { data, error } = await admin.rpc("run_audit_ip_retention");
  if (error) {
    return Response.json({ status: "failed" }, { status: 500 });
  }
  return Response.json(
    { status: "ok", redacted: typeof data === "number" ? data : null },
    { headers: { "Cache-Control": "no-store" } },
  );
}
