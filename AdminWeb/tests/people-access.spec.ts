import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";

import { messages } from "../src/localization/messages";

test.describe.configure({ mode: "serial" });

const copy = messages.en.auth;
const runToken = crypto.randomUUID().slice(0, 8);
const CLIMBER_ID = "90000000-0000-4000-8000-000000000001";

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

async function signIn(page: Page, email = "fixture-admin@bloclens.invalid") {
  await page.goto("/sign-in");
  await page.getByLabel(copy.signIn.emailLabel).fill(email);
  await page.getByLabel(copy.signIn.passwordLabel).fill("BlocLensLocalTest1!");
  await page.getByRole("button", { name: copy.signIn.submit }).click();
  await expect(page).toHaveURL(/\/overview$/);
}

async function userDetail(page: Page) {
  await page.goto(`/people/${CLIMBER_ID}`);
  await expect(page.getByRole("heading", { name: "Fixture Climber One" })).toBeVisible();
}

test("applies a publishing restriction and enforces it on publishing", async ({ page }) => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  const climber = await sessionClient("fixture-climber-1@bloclens.invalid");
  try {
    await signIn(page);
    await userDetail(page);
    await page.getByRole("button", { name: /Apply restriction/ }).click();
    const penaltyDialog = page.getByRole("dialog", { name: "Apply restriction" });
    await penaltyDialog.getByLabel("Restriction", { exact: true }).selectOption("publishing_restriction");
    await penaltyDialog.getByLabel("Reason").fill(`Gate restriction ${runToken}`);
    await penaltyDialog.getByRole("button", { name: "Apply restriction", exact: true }).click();
    await expect(
      page.getByText("publishing_restriction", { exact: true }),
    ).toBeVisible({ timeout: 10000 });

    // The restricted climber cannot publish but keeps the report channel.
    const { error: publishError } = await climber.from("routes").insert({
      gym_id: "10000000-0000-4000-8000-000000000001",
      wall_zone_id: "20000000-0000-4000-8000-000000000001",
      colour: `Gate ${runToken} blocked`,
      gym_grade: 1,
      created_by: CLIMBER_ID,
    });
    expect(publishError?.code).toBe("42501");

    const { error: reportError } = await climber.from("content_reports").insert({
      target_type: "route",
      target_id: "30000000-0000-4000-8000-000000000001",
      category: "spam",
      reporter_id: CLIMBER_ID,
      details: `Gate report ${runToken}`,
      status: "open",
    });
    expect(reportError).toBeNull();
  } finally {
    // Cleanup runs even when assertions fail so later suites stay hermetic.
    const { data: summary } = await admin.rpc("admin_user_summary", {
      target_user_id: CLIMBER_ID,
    });
    const active = (summary as Array<{ active_restrictions: Array<{ action_id: string }> }>)[0]
      ?.active_restrictions[0];
    if (active) {
      await admin.rpc("admin_reverse_user_penalty", {
        penalty_action_id: active.action_id,
        reason: `Gate cleanup ${runToken}`,
        idempotency_key: crypto.randomUUID(),
      });
    }
  }
});

test("reverses a timed suspension from the user detail page", async ({ page }) => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  const { data: applied, error: applyError } = await admin.rpc("admin_apply_user_penalty", {
    target_user_id: CLIMBER_ID,
    penalty_kind: "timed_suspension",
    ends_at: new Date(Date.now() + 86400000).toISOString(),
    reason: `Gate suspension ${runToken}`,
    idempotency_key: crypto.randomUUID(),
  });
  if (applyError) throw applyError;
  expect((applied as Array<{ ok: boolean }>)[0]?.ok).toBe(true);

  await signIn(page);
  await userDetail(page);
  await expect(page.getByText("timed_suspension", { exact: true })).toBeVisible();
  await page.getByRole("button", { name: "Reverse", exact: true }).click();
  // The reversal itself keeps the kind in history; the restrictions
  // section must report no ACTIVE restriction instead.
  await expect(page.getByText("No active restrictions.")).toBeVisible({ timeout: 10000 });
});

test("invites and revokes a staff invitation from the staff page", async ({ page }) => {
  const email = `gate-invite-${runToken}@bloclens.invalid`;
  await signIn(page);
  await page.goto("/staff");
  await page.getByRole("button", { name: "Invite staff" }).click();
  await page.getByLabel("Email address").fill(email);
  await page.getByLabel("Reason", { exact: false }).fill(`Gate invitation ${runToken}`);
  await page.getByRole("button", { name: "Send invitation" }).click();
  // Success closes the dialog; assert the durable outcome (our pending row).
  await expect(page.getByRole("dialog", { name: "Invite staff" })).toBeHidden({ timeout: 15000 });
  const row = page.getByRole("listitem").filter({ hasText: email });
  await row.getByRole("button", { name: "Revoke" }).click();
  const dialog = page.getByRole("dialog", { name: "Revoke" });
  await dialog.getByLabel("Reason", { exact: false }).fill(`Gate revocation ${runToken}`);
  await dialog.getByRole("button", { name: "Revoke", exact: true }).click();
  await expect(row.getByText("Revoked", { exact: true })).toBeVisible({ timeout: 10000 });
});
