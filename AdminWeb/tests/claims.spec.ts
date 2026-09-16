import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";

import { messages } from "../src/localization/messages";

test.describe.configure({ mode: "serial" });

const copy = messages.en.auth;
const runToken = crypto.randomUUID().slice(0, 8);
const GYM = "10000000-0000-4000-8000-000000000001";

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

async function fileClaim(client: SupabaseClient, email: string): Promise<string> {
  const userId = (await client.auth.getUser()).data.user?.id;
  const { data, error } = await client
    .from("gym_claims")
    .insert({
      gym_id: GYM,
      applicant_id: userId,
      domain_email: email,
      verification_method: "manual_review",
      status: "submitted",
    })
    .select("id")
    .single();
  if (error) throw error;
  return (data as { id: string }).id;
}

async function claimStatus(admin: SupabaseClient, id: string): Promise<string> {
  const { data, error } = await admin
    .from("gym_claims")
    .select("status")
    .eq("id", id)
    .single();
  if (error) throw error;
  return (data as { status: string }).status;
}

test("approves a claim and mints the verified membership", async ({ page }) => {
  const climber = await sessionClient("fixture-gym-official@bloclens.invalid");
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  const applicantId = (await climber.auth.getUser()).data.user?.id ?? "";
  const email = `gate-approve-${runToken}@example.invalid`;
  const claimId = await fileClaim(climber, email);

  // Lapse the seed membership so approval must genuinely re-mint it.
  await admin
    .from("gym_memberships")
    .update({ revoked_at: new Date().toISOString() })
    .eq("gym_id", GYM)
    .eq("user_id", applicantId);

  await signIn(page);
  await page.goto("/people/claims");
  await page.getByRole("cell", { name: "Fixture Gym Official" }).click();
  await expect(page.getByRole("dialog", { name: "Gym claims" })).toBeVisible();
  await expect(page.getByText(`Fixture Gym Official · ${email}`)).toBeVisible();
  await page.getByRole("button", { name: "Approve", exact: true }).click();
  await page.getByLabel("Review note").fill(`Gate approval ${runToken}`);
  await page.getByRole("button", { name: "Confirm decision" }).click();
  await expect(page.getByRole("dialog", { name: "Approve" })).toBeHidden({ timeout: 10000 });

  expect(await claimStatus(admin, claimId)).toBe("approved");
  const { data: membership } = await admin
    .from("gym_memberships")
    .select("revoked_at")
    .eq("gym_id", GYM)
    .eq("user_id", applicantId)
    .single();
  expect((membership as { revoked_at: string | null }).revoked_at).toBeNull();
});

test("rejects a claim without creating a membership", async ({ page }) => {
  const climber = await sessionClient("fixture-trusted@bloclens.invalid");
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  const userId = (await climber.auth.getUser()).data.user?.id;
  const email = `gate-reject-${runToken}@example.invalid`;
  const claimId = await fileClaim(climber, email);

  await signIn(page);
  await page.goto("/people/claims");
  await page.getByRole("cell", { name: "Fixture Trusted" }).click();
  await expect(page.getByRole("dialog", { name: "Gym claims" })).toBeVisible();
  await expect(page.getByText(`Fixture Trusted · ${email}`)).toBeVisible();
  await page.getByRole("button", { name: "Reject", exact: true }).click();
  await page.getByLabel("Review note").fill(`Gate rejection ${runToken}`);
  await page.getByRole("button", { name: "Confirm decision" }).click();
  await expect(page.getByRole("dialog", { name: "Reject" })).toBeHidden({ timeout: 10000 });

  expect(await claimStatus(admin, claimId)).toBe("rejected");
  // The seed membership for the official is untouched; the rejected
  // applicant gains nothing.
  const { data } = await admin
    .from("gym_memberships")
    .select("user_id")
    .eq("gym_id", GYM)
    .eq("user_id", userId ?? "");
  expect((data as unknown[]).length).toBe(0);
});

test("withholds claim decisions from Moderators", async ({ page }) => {
  await signIn(page, "fixture-moderator@bloclens.invalid");
  await page.goto("/people/claims");
  await expect(page).toHaveURL(/\/access-denied$/, { timeout: 10000 });
});
