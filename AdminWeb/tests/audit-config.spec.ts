import { createClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";

import { messages } from "../src/localization/messages";

const copy = messages.en.auth;

async function signIn(page: Page, email = "fixture-admin@bloclens.invalid") {
  await page.goto("/sign-in");
  await page.getByLabel(copy.signIn.emailLabel).fill(email);
  await page.getByLabel(copy.signIn.passwordLabel).fill("BlocLensLocalTest1!");
  await page.getByRole("button", { name: copy.signIn.submit }).click();
  await expect(page).toHaveURL(/\/overview$/);
}

for (const { width, height } of [
  { width: 1440, height: 1000 },
  { width: 1024, height: 768 },
  { width: 390, height: 844 },
]) {
  test(`audit and configuration render without overflow at ${width}x${height}`, async ({
    page,
  }) => {
    await page.setViewportSize({ width, height });
    await page.emulateMedia({ reducedMotion: "reduce" });
    await signIn(page);
    await page.goto("/audit");
    await expect(page.getByLabel("Actor")).toBeVisible();
    // Wait for settled content (rows or empty state), webfont swap, then
    // compare against clientWidth: innerWidth shrinks under a vertical
    // scrollbar and would false-positive on tall tables.
    await expect(
      page.getByRole("table").or(page.getByText("No matching audit events")),
    ).toBeVisible();
    await page.evaluate(() => document.fonts.ready.then(() => true));
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1,
      ),
    ).toBe(true);
    await page.screenshot({ path: test.info().outputPath(`audit-${width}.png`), fullPage: true });

    await page.goto("/configuration");
    await expect(page.getByRole("heading", { name: "Review queue" })).toBeVisible();
    await page.evaluate(() => document.fonts.ready.then(() => true));
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1,
      ),
    ).toBe(true);
    await page.screenshot({
      path: test.info().outputPath(`configuration-${width}.png`),
      fullPage: true,
    });
  });
}

test("audit lookup finds a filter-matching event and exports CSV", async ({ page }) => {
  await signIn(page);
  // Seed one audited action through the invitation route first.
  const invite = await page.request.post("/api/staff/invitations", {
    headers: { origin: "http://127.0.0.1:3000" },
    data: {
      email: `gate-audit-${crypto.randomUUID()}@bloclens.invalid`,
      role: "moderator",
      reason: "Gate audit lookup seed",
    },
  });
  expect(invite.status()).toBe(202);

  await page.goto("/audit?action=staff.invitation.created");
  await expect(page.getByRole("columnheader", { name: "Action" })).toBeVisible();
  await page.getByRole("cell", { name: "staff.invitation.created" }).first().click();
  await expect(page.getByRole("dialog", { name: "Audit event" })).toBeVisible();
  await page.keyboard.press("Escape");

  const download = await Promise.all([
    page.waitForEvent("download"),
    page.getByRole("link", { name: "Export CSV" }).click(),
  ]).then(([value]) => value);
  expect(Boolean(await download.path())).toBe(true);
});

test("configuration conflict surfaces instead of overwriting", async ({ page }) => {
  await signIn(page);
  await page.goto("/configuration");
  // A concurrent change bumps the version after this form rendered,
  // so submitting it must conflict instead of overwriting.
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error("Local Supabase test credentials are required");
  const admin = createClient(url, key, { auth: { persistSession: false } });
  await admin.auth.signInWithPassword({
    email: "fixture-admin@bloclens.invalid",
    password: "BlocLensLocalTest1!",
  });
  const current = await admin
    .from("operational_configuration")
    .select("version")
    .eq("key", "review.queue.order")
    .single();
  await admin.rpc("admin_update_configuration", {
    config_key: "review.queue.order",
    config_value: "oldest_first",
    reason: "Gate concurrent bump",
    expected_version: (current.data as { version: number }).version,
    idempotency_key: crypto.randomUUID(),
  });
  await page.getByLabel("Default queue order").selectOption("severity_first");
  await page.getByLabel("Reason").first().fill("Gate conflict probe");
  await page.getByRole("button", { name: "Save changes" }).first().click();
  await expect(page.getByText(/Someone else updated configuration/)).toBeVisible({
    timeout: 10000,
  });
});

test("moderators browse audit but never reach configuration", async ({ page }) => {
  await signIn(page, "fixture-moderator@bloclens.invalid");
  await page.goto("/audit");
  await expect(page.getByRole("search")).toBeVisible();
  await page.goto("/configuration");
  await expect(page).toHaveURL(/\/access-denied$/, { timeout: 10000 });
});
