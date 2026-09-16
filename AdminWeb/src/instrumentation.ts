/**
 * Next.js instrumentation hook. Kept deliberately side-effect free: it only
 * records that the runtime booted with the expected public configuration.
 * Heavyweight tracing is out of scope; correlation travels explicitly via
 * `logEvent(..., traceId)` because RSC boundaries do not propagate
 * AsyncLocalStorage.
 */
export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    const { env } = await import("./lib/env");
    void env.NEXT_PUBLIC_SUPABASE_URL;
  }
}
