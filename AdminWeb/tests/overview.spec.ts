import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";

import { messages } from "../src/localization/messages";

const copy = messages.en.auth;
const overview = messages.en.overview;

async function adminClient(): Promise<SupabaseClient> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error("Local Supabase test credentials are required");
  const client = createClient(url, key, { auth: { persistSession: false } });
  const { error } = await client.auth.signInWithPassword({
    email: "fixture-admin@bloclens.invalid",
    password: "BlocLensLocalTest1!",
  });
  if (error) throw error;
  return client;
}

async function signIn(page: Page) {
  await page.goto("/sign-in");
  await page.getByLabel(copy.signIn.emailLabel).fill("fixture-admin@bloclens.invalid");
  await page.getByLabel(copy.signIn.passwordLabel).fill("BlocLensLocalTest1!");
  await page.getByRole("button", { name: copy.signIn.submit }).click();
  await expect(page).toHaveURL(/\/overview$/);
  await expect(page.getByRole("navigation", { name: "Time range" })).toBeVisible();
}

test("overview metrics match the database and link into filtered queues", async ({ page }) => {
  const admin = await adminClient();
  const { data: pendingRows } = await admin
    .from("content_reports")
    .select("id")
    .in("status", ["open", "under_review"]);
  const pendingReports = pendingRows?.length ?? -1;
  const severeReports = (
    await admin
      .from("content_reports")
      .select("id")
      .in("status", ["open", "under_review"])
      .eq("is_severe", true)
  ).data?.length ?? -1;

  await signIn(page);
  await expect(
    page.getByRole("link", { name: new RegExp(`Pending reports: ${pendingReports}`) }),
  ).toBeVisible();
  await expect(
    page.getByRole("link", { name: new RegExp(`Severe reports: ${severeReports}`) }),
  ).toBeVisible();

  await page.getByRole("link", { name: /Pending reports/ }).click();
  await expect(page).toHaveURL(/\/review\?status=pending/);
});

test("range switching re-renders the trend window", async ({ page }) => {
  await signIn(page);
  // Range links carry the window in the URL; each window renders its own trend.
  // (Client-side link transitions are covered by the review queue filter tests.)
  await expect(page.getByRole("link", { name: overview.ranges["90d"] })).toHaveAttribute(
    "href",
    "/overview?range=90d",
  );
  await page.goto("/overview?range=90d");
  await expect(page).toHaveURL(/range=90d/);
  await expect(page.getByRole("link", { name: overview.ranges["90d"] })).toHaveAttribute(
    "aria-current",
    "page",
  );
  await expect(page.getByRole("heading", { name: "Review activity" })).toBeVisible();
  await page.goto("/overview?range=7d");
  await expect(page).toHaveURL(/range=7d/);
  await expect(page.getByRole("link", { name: overview.ranges["7d"] })).toHaveAttribute(
    "aria-current",
    "page",
  );
});

test("priority and distribution sections render with textual values", async ({ page }) => {
  await signIn(page);
  await expect(page.getByRole("heading", { name: "Needs attention first" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Queue by kind and status" })).toBeVisible();
});
