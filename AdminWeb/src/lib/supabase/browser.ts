import { createBrowserClient as createSupabaseBrowserClient } from "@supabase/ssr";

import { env } from "../env";

export function createBrowserClient() {
  return createSupabaseBrowserClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
}
