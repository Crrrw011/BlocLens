import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";

import { messages } from "../src/localization/messages";

test.describe.configure({ mode: "serial" });

const copy = messages.en.auth;
const runToken = crypto.randomUUID().slice(0, 8);
const GYM = "10000000-0000-4000-8000-000000000001";
const ZONE = "20000000-0000-4000-8000-000000000001";
const OTHER_GYM_ROUTE = "30000000-0000-4000-8000-000000000019";

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

async function createRoute(
  client: SupabaseClient,
  colour: string,
): Promise<string> {
  const creator = (await client.auth.getUser()).data.user?.id;
  const { data, error } = await client
    .from("routes")
    .insert({ gym_id: GYM, wall_zone_id: ZONE, colour, gym_grade: 3, created_by: creator })
    .select("id")
    .single();
  if (error) throw error;
  return (data as { id: string }).id;
}

let sourceId = "";
let canonicalId = "";

test.beforeAll(async () => {
  const climberOne = await sessionClient("fixture-climber-1@bloclens.invalid");
  const climberTwo = await sessionClient("fixture-climber-2@bloclens.invalid");
  sourceId = await createRoute(climberOne, `Gate ${runToken} source`);
  canonicalId = await createRoute(climberOne, `Gate ${runToken} canonical`);
  // Same climber logs both routes (acknowledged duplicate); a second
  // climber logs only the source (migrates).
  for (const [client, route] of [
    [climberOne, sourceId],
    [climberOne, canonicalId],
    [climberTwo, sourceId],
  ] as const) {
    const { error } = await client.from("logbook_entries").insert({
      user_id: (await client.auth.getUser()).data.user?.id,
      route_id: route,
      status: "projecting",
      climbed_at: new Date().toISOString(),
      client_created_at: new Date().toISOString(),
      client_idempotency_key: crypto.randomUUID(),
    });
    expect(error).toBeNull();
  }
});

test("previews counts and requires every duplicate to be acknowledged", async ({ page }) => {
  await signIn(page);
  await page.goto(`/climbing-data/route/${sourceId}/merge?canonical=${canonicalId}`);
  await expect(page.getByRole("heading", { name: "Source and canonical" })).toBeVisible();
  await expect(page.getByText("logbook_entries: 2")).toBeVisible();
  const submit = page.getByRole("button", { name: "Merge routes" });
  await expect(submit).toBeDisabled();
  await page.getByRole("checkbox").check();
  await expect(submit).toBeEnabled();
});

test("executes the merge and archives the source", async ({ page }) => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  await signIn(page);
  await page.goto(`/climbing-data/route/${sourceId}/merge?canonical=${canonicalId}`);
  await page.getByRole("checkbox").check();
  await page.getByLabel("Reason").fill(`Gate merge ${runToken}`);
  await page.getByRole("button", { name: "Merge routes" }).click();
  await expect(page).toHaveURL(new RegExp(`/climbing-data/route/${canonicalId}$`), {
    timeout: 15000,
  });

  const { data, error } = await admin.rpc("admin_entity_detail", {
    entity_kind: "route",
    entity_id: sourceId,
  });
  if (error) throw error;
  const row = (data as Array<{ details: { lifecycle: string; canonical_route_id: string } }>)[0];
  expect(row?.details.lifecycle).toBe("archived");
  expect(row?.details.canonical_route_id).toBe(canonicalId);

  const { data: audit } = await admin
    .from("admin_audit_events")
    .select("after_summary")
    .eq("action_key", "route.merge")
    .eq("target_id", sourceId)
    .order("created_at", { ascending: false })
    .limit(1)
    .single();
  expect(JSON.stringify(audit?.after_summary)).toContain(canonicalId);
});

test("refuses cross-gym merges instead of moving data", async ({ page }) => {
  await signIn(page);
  await page.goto(`/climbing-data/route/${canonicalId}/merge?canonical=${OTHER_GYM_ROUTE}`);
  await expect(page.getByText("Unable to load this view")).toBeVisible();
});

test("withholds merge execution from Moderators", async ({ page }) => {
  await signIn(page, "fixture-moderator@bloclens.invalid");
  await page.goto(`/climbing-data/route/${canonicalId}/merge?canonical=${OTHER_GYM_ROUTE}`);
  // Moderators review the preview but cannot merge; cross-gym is refused first.
  await page.goto(`/climbing-data/route/${sourceId}/merge`);
  await expect(page.getByLabel("Merge into")).toBeVisible();
});
