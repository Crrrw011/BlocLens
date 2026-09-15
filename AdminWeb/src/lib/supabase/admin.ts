import "server-only";

import { createClient } from "@supabase/supabase-js";

import { env } from "../env";

export function createAdminClient() {
  const secret = process.env.SUPABASE_SECRET_KEY;
  if (!secret) throw new Error("Server Auth administration is not configured");
  return createClient(env.NEXT_PUBLIC_SUPABASE_URL, secret, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
}
