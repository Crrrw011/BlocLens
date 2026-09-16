import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";

import { messages } from "../src/localization/messages";

test.describe.configure({ mode: "serial" });

const copy = messages.en.auth;

function supabaseUrl(): { url: string; key: string } {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error("Local Supabase test credentials are required");
  return { url, key };
}

async function sessionClient(email: string): Promise<SupabaseClient> {
  const { url, key } = supabaseUrl();
  const client = createClient(url, key, { auth: { persistSession: false } });
  const { error } = await client.auth.signInWithPassword({
    email,
    password: "BlocLensLocalTest1!",
  });
  if (error) throw error;
  return client;
}

async function signIn(page: Page, email: string) {
  await page.goto("/sign-in");
  await page.getByLabel(copy.signIn.emailLabel).fill(email);
  await page.getByLabel(copy.signIn.passwordLabel).fill("BlocLensLocalTest1!");
  await page.getByRole("button", { name: copy.signIn.submit }).click();
  // Wait for the sign-in round-trip before navigating: an immediate goto
  // would abort the in-flight POST and leave the session unset.
  await expect(page).toHaveURL(/(\/overview$|\/access-denied$)/, { timeout: 15000 });
}

const ADMIN = "fixture-admin@bloclens.invalid";
const MODERATOR = "fixture-moderator@bloclens.invalid";
const CLIMBER = "fixture-climber-1@bloclens.invalid";
const MODERATOR_ID = "90000000-0000-4000-8000-000000000006";

const STAFF_ROUTES = ["/overview", "/review", "/climbing-data/route", "/people", "/audit"];
const ADMIN_ONLY_ROUTES = ["/staff", "/people/claims", "/configuration"];

test("Moderator reaches staff workflows but not administration", async ({ page }) => {
  await signIn(page, MODERATOR);
  await expect(page).toHaveURL(/\/overview$/);
  for (const route of STAFF_ROUTES) {
    await page.goto(route);
    await expect(page).not.toHaveURL(/access-denied/, { timeout: 10000 });
  }
  for (const route of ADMIN_ONLY_ROUTES) {
    await page.goto(route);
    await expect(page).toHaveURL(/\/access-denied$/, { timeout: 10000 });
  }
});

test("Administrator reaches every destination", async ({ page }) => {
  await signIn(page, ADMIN);
  await expect(page).toHaveURL(/\/overview$/);
  for (const route of [...STAFF_ROUTES, ...ADMIN_ONLY_ROUTES]) {
    await page.goto(route);
    await expect(page).not.toHaveURL(/access-denied/, { timeout: 10000 });
  }
});

test("non-staff users are denied protected content and APIs", async ({ page }) => {
  await signIn(page, CLIMBER);
  await page.goto("/overview");
  await expect(page).toHaveURL(/\/access-denied$/, { timeout: 10000 });
  const exportResponse = await page.request.get(
    "/api/audit/export?from=2026-09-01T00:00:00.000Z&to=2026-09-02T00:00:00.000Z",
  );
  expect(exportResponse.status()).toBe(403);
});

test("deactivated staff loses access without a session change", async ({ page }) => {
  const admin = await sessionClient(ADMIN);
  // Deactivate the moderator through the protected function.
  const { data: deactivated, error: deactivateError } = await admin.rpc(
    "admin_set_staff_active",
    {
      target_user_id: MODERATOR_ID,
      make_active: false,
      reason: "Gate matrix deactivation",
      idempotency_key: crypto.randomUUID(),
    },
  );
  if (deactivateError) throw deactivateError;
  expect((deactivated as Array<{ ok: boolean }>)[0]?.ok).toBe(true);

  await page.goto("/sign-in");
  await page.getByLabel(copy.signIn.emailLabel).fill(MODERATOR);
  await page.getByLabel(copy.signIn.passwordLabel).fill("BlocLensLocalTest1!");
  await page.getByRole("button", { name: copy.signIn.submit }).click();
  await expect(page).toHaveURL(/\/access-denied$/, { timeout: 15000 });

  // Restore the fixture for later suites.
  const { data: reactivated, error: reactivateError } = await admin.rpc(
    "admin_set_staff_active",
    {
      target_user_id: MODERATOR_ID,
      make_active: true,
      reason: "Gate matrix restoration",
      idempotency_key: crypto.randomUUID(),
    },
  );
  if (reactivateError) throw reactivateError;
  expect((reactivated as Array<{ ok: boolean }>)[0]?.ok).toBe(true);

  // The browser session persists; restored access applies on next load.
  await page.goto("/overview");
  await expect(page).toHaveURL(/\/overview$/, { timeout: 15000 });
});
