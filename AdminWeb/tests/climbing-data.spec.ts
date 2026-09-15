import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";

import { messages } from "../src/localization/messages";

test.describe.configure({ mode: "serial" });

const copy = messages.en.auth;
const runToken = crypto.randomUUID().slice(0, 8);
const GYM = "10000000-0000-4000-8000-000000000001";
const ZONE = "20000000-0000-4000-8000-000000000001";

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

async function routeIdByColour(admin: SupabaseClient, colour: string): Promise<string> {
  const { data, error } = await admin.rpc("admin_list_entities", {
    entity_kind: "route",
    status_filter: "all",
    search_text: colour,
    gym_id: null,
    page_after: null,
    page_size: 5,
  });
  if (error) throw error;
  const row = (data as Array<{ id: string }>)[0];
  if (!row) throw new Error(`seed route missing: ${colour}`);
  return row.id;
}

async function routeLifecycle(admin: SupabaseClient, id: string): Promise<string> {
  const { data, error } = await admin.rpc("admin_entity_detail", {
    entity_kind: "route",
    entity_id: id,
  });
  if (error) throw error;
  const row = (data as Array<{ details: { lifecycle: string; moderation_status: string } }>)[0];
  if (!row) throw new Error("route detail missing");
  return `${row.details.lifecycle}/${row.details.moderation_status}`;
}

test.beforeAll(async () => {
  const climber = await sessionClient("fixture-climber-1@bloclens.invalid");
  const creator = (await climber.auth.getUser()).data.user?.id;
  for (const tag of ["edit", "archive", "hide"]) {
    const { error } = await climber.from("routes").insert({
      gym_id: GYM,
      wall_zone_id: ZONE,
      colour: `Gate ${runToken} ${tag}`,
      gym_grade: 3,
      created_by: creator,
    });
    expect(error).toBeNull();
  }
});

test("search, status filter, and deep links share the queue state", async ({ page }) => {
  await signIn(page);
  await page.goto(`/climbing-data/route?q=${runToken}`);
  await expect(page.getByRole("cell", { name: `Gate ${runToken} edit` })).toBeVisible();
  await page.getByRole("link", { name: "Hidden" }).click();
  await expect(page).toHaveURL(/status=hidden/);
  await expect(page.getByText("No matching records")).toBeVisible();

  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  const id = await routeIdByColour(admin, `Gate ${runToken} edit`);
  await page.goto(`/climbing-data/route/${id}`);
  await expect(page.getByRole("heading", { name: "Identifiers" })).toBeVisible();
});

test("edits a route colour and keeps the audit trail", async ({ page }) => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  const id = await routeIdByColour(admin, `Gate ${runToken} edit`);
  await signIn(page);
  await page.goto(`/climbing-data/route/${id}`);
  await page.getByLabel("Colour").fill(`Gate ${runToken} edited`);
  await page.getByLabel("Reason", { exact: false }).first().fill(`Gate edit ${runToken}`);
  await page.getByRole("button", { name: "Save changes" }).click();
  await expect(page.getByText("Saved")).toBeVisible({ timeout: 10000 });

  const { data } = await admin
    .from("admin_audit_events")
    .select("after_summary")
    .eq("action_key", "climbing.entity_updated")
    .order("created_at", { ascending: false })
    .limit(1)
    .single();
  expect(JSON.stringify(data?.after_summary)).toContain(`Gate ${runToken} edited`);
});

test("archives and restores a route as an Administrator", async ({ page }) => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  const id = await routeIdByColour(admin, `Gate ${runToken} archive`);
  await signIn(page);
  await page.goto(`/climbing-data/route/${id}`);
  await page.getByRole("button", { name: "Archive", exact: true }).click();
  const archiveDialog = page.getByRole("dialog");
  await archiveDialog.getByLabel("Reason").fill(`Gate archive ${runToken}`);
  await archiveDialog.getByRole("button", { name: "Confirm" }).click();
  await expect(page.getByRole("dialog")).toBeHidden({ timeout: 10000 });
  expect(await routeLifecycle(admin, id)).toBe("archived/visible");

  await page.getByRole("button", { name: "Restore", exact: true }).click();
  const unarchiveDialog = page.getByRole("dialog");
  await unarchiveDialog.getByLabel("Reason").fill(`Gate unarchive ${runToken}`);
  await unarchiveDialog.getByRole("button", { name: "Confirm" }).click();
  await expect(page.getByRole("dialog")).toBeHidden({ timeout: 10000 });
  expect(await routeLifecycle(admin, id)).toBe("active/visible");
});

test("hides and restores a route as a Moderator", async ({ page }) => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  const id = await routeIdByColour(admin, `Gate ${runToken} hide`);
  await signIn(page, "fixture-moderator@bloclens.invalid");
  await page.goto(`/climbing-data/route/${id}`);
  // Moderators hide and restore but never archive or delete.
  await expect(page.getByRole("button", { name: "Archive", exact: true })).toBeHidden();
  await expect(page.getByRole("button", { name: "Delete…" })).toBeHidden();
  await page.getByRole("button", { name: "Hide", exact: true }).click();
  const hideDialog = page.getByRole("dialog");
  await hideDialog.getByLabel("Reason").fill(`Gate hide ${runToken}`);
  await hideDialog.getByRole("button", { name: "Confirm" }).click();
  await expect(page.getByRole("dialog")).toBeHidden({ timeout: 10000 });
  expect(await routeLifecycle(admin, id)).toBe("temporarily_hidden/temporarily_hidden");

  await page.getByRole("button", { name: "Restore", exact: true }).click();
  const unhideDialog = page.getByRole("dialog");
  await unhideDialog.getByLabel("Reason").fill(`Gate unhide ${runToken}`);
  await unhideDialog.getByRole("button", { name: "Confirm" }).click();
  await expect(page.getByRole("dialog")).toBeHidden({ timeout: 10000 });
  expect(await routeLifecycle(admin, id)).toBe("active/visible");
});
