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

async function entityExists(
  admin: SupabaseClient,
  kind: string,
  id: string,
): Promise<boolean> {
  const { data, error } = await admin.rpc("admin_entity_detail", {
    entity_kind: kind,
    entity_id: id,
  });
  if (error) throw error;
  return (data as unknown[]).length > 0;
}

let routeId = "";
let linkId = "";
let commentId = "";

test.beforeAll(async () => {
  const climber = await sessionClient("fixture-climber-1@bloclens.invalid");
  const userId = (await climber.auth.getUser()).data.user?.id;
  const { data: route, error: routeError } = await climber
    .from("routes")
    .insert({ gym_id: GYM, wall_zone_id: ZONE, colour: `Gate ${runToken} doomed`, gym_grade: 2, created_by: userId })
    .select("id")
    .single();
  expect(routeError).toBeNull();
  routeId = (route as { id: string }).id;

  const { data: link, error: linkError } = await climber
    .from("beta_links")
    .insert({
      route_id: routeId,
      public_url: "https://example.invalid/beta/gate",
      normalised_url: "https://example.invalid/beta/gate",
      normalised_url_hash: `gate-fixture-hash-${runToken}-000000000001`,
      platform: "youtube",
      original_author_display_name: "Gate Author",
      original_post_url: "https://example.invalid/post/gate",
      submitted_by: userId,
    })
    .select("id")
    .single();
  expect(linkError).toBeNull();
  linkId = (link as { id: string }).id;

  const { data: comment, error: commentError } = await climber
    .from("beta_comments")
    .insert({ beta_link_id: linkId, author_id: userId, body: `Gate comment ${runToken}` })
    .select("id")
    .single();
  expect(commentError).toBeNull();
  commentId = (comment as { id: string }).id;
});

test("withholds deletion while a beta link still has comments", async ({ page }) => {
  await signIn(page);
  await page.goto(`/climbing-data/beta_link/${linkId}`);
  await page.getByRole("button", { name: "Delete…" }).click();
  await expect(page.getByText("beta_comments: 1")).toBeVisible();
  await expect(page.getByRole("button", { name: "Continue" })).toBeHidden();
  await expect(page.getByText(/cannot be deleted/)).toBeVisible();
});

test("deletes a comment, then its link, then its bare route", async ({ page }) => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  await signIn(page);

  for (const [kind, id, reason] of [
    ["route_comment", commentId, `Gate comment deletion ${runToken}`],
    ["beta_link", linkId, `Gate link deletion ${runToken}`],
    ["route", routeId, `Gate route deletion ${runToken}`],
  ] as const) {
    await page.goto(`/climbing-data/${kind}/${id}`);
    await page.getByRole("button", { name: "Delete…" }).click();
    await page.getByRole("button", { name: "Continue" }).click();
    const dialog = page.getByRole("dialog", { name: "Type DELETE to confirm" });
    await dialog.getByLabel("Reason").fill(reason);
    await dialog.getByLabel("Type DELETE in capitals").fill("delete");
    await expect(dialog.getByRole("button", { name: "Delete permanently" })).toBeDisabled();
    await dialog.getByLabel("Type DELETE in capitals").fill("DELETE");
    await dialog.getByRole("button", { name: "Delete permanently" }).click();
    await expect(page).toHaveURL(new RegExp(`/climbing-data/${kind}$`), { timeout: 15000 });
    expect(await entityExists(admin, kind, id)).toBe(false);
  }
});

test("leaves an audit tombstone for every deletion", async () => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  const { data, error } = await admin
    .from("admin_audit_events")
    .select("target_id,after_summary")
    .eq("action_key", "entity.deleted")
    .order("created_at", { ascending: false })
    .limit(10);
  if (error) throw error;
  const ids = (data as Array<{ target_id: string }>).map((row) => row.target_id);
  expect(ids).toContain(commentId);
  expect(ids).toContain(linkId);
  expect(ids).toContain(routeId);
});

test("withholds deletion from Moderators", async ({ page }) => {
  await signIn(page, "fixture-moderator@bloclens.invalid");
  await page.goto("/climbing-data/route?status=active");
  await page.getByRole("cell", { name: "Blue" }).first().click();
  await expect(page.getByRole("dialog", { name: "Record details" })).toBeVisible();
  await page.getByRole("link", { name: "Open full record" }).click();
  await expect(page.getByRole("heading", { name: "Identifiers" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Delete…" })).toBeHidden();
});
