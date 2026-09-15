import { expect, test, type Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { messages } from "../src/localization/messages";

test.describe.configure({ mode: "serial" });

const copy = messages.en.auth;
const decisions = messages.en.review.decisions;
const runToken = crypto.randomUUID().slice(0, 8);

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

async function openItem(page: Page, token: string, category: string) {
  await page.goto(`/review?status=pending&q=${token}`);
  await page.getByRole("cell", { name: category, exact: true }).click();
  await expect(page.getByRole("dialog", { name: "Review details" })).toBeVisible();
}

async function confirmDecision(page: Page, action: string, reason: string) {
  await page.getByRole("button", { name: action, exact: true }).click();
  await expect(page.getByRole("dialog", { name: /Confirm review decision/ })).toBeVisible();
  await page.getByLabel(decisions.reasonLabel).fill(reason);
  await page.getByRole("button", { name: decisions.confirm }).click();
  await expect(page.getByRole("dialog", { name: /Confirm review decision/ })).toBeHidden({
    timeout: 10000,
  });
}

test.beforeAll(async () => {
  // Normal-priority fixtures only: severe reports auto-hide their target.
  // Fixtures are filed as the climber through RLS; no service key is used.
  const climber = await sessionClient("fixture-climber-1@bloclens.invalid");
  const climberTwo = await sessionClient("fixture-climber-2@bloclens.invalid");
  // The (target, reporter) pair is unique: rotate reporters across fixtures.
  const reports = [
    { tag: "dismiss", category: "spam", route: "30000000-0000-4000-8000-000000000004", reporter: "90000000-0000-4000-8000-000000000001" },
    { tag: "hide", category: "spam", route: "30000000-0000-4000-8000-000000000003", reporter: "90000000-0000-4000-8000-000000000001" },
    { tag: "escalate", category: "other", route: "30000000-0000-4000-8000-000000000004", reporter: "90000000-0000-4000-8000-000000000002" },
    { tag: "conflict", category: "spam", route: "30000000-0000-4000-8000-000000000003", reporter: "90000000-0000-4000-8000-000000000002" },
  ];
  const clients: Record<string, SupabaseClient> = {
    "90000000-0000-4000-8000-000000000001": climber,
    "90000000-0000-4000-8000-000000000002": climberTwo,
  };
  for (const report of reports) {
    const { error } = await clients[report.reporter]!.from("content_reports").insert({
      target_type: "route",
      target_id: report.route,
      category: report.category,
      reporter_id: report.reporter,
      details: `Gate flow ${runToken} ${report.tag}`,
      status: "open",
    });
    expect(error).toBeNull();
  }
  const { error } = await climber.from("route_corrections").insert({
    route_id: "30000000-0000-4000-8000-000000000004",
    submitted_by: "90000000-0000-4000-8000-000000000001",
    issue_key: "grade",
    explanation: `Gate flow ${runToken} accept-admin`,
    status: "open",
  });
  expect(error).toBeNull();
  const { error: secondError } = await climberTwo.from("route_corrections").insert({
    route_id: "30000000-0000-4000-8000-000000000002",
    submitted_by: "90000000-0000-4000-8000-000000000002",
    issue_key: "holds",
    explanation: `Gate flow ${runToken} accept-view`,
    status: "open",
  });
  expect(secondError).toBeNull();
});

test("queue filters narrow the list through the URL", async ({ page }) => {
  await signIn(page);
  await page.goto("/review?status=pending");
  await page.getByRole("link", { name: "Resolved" }).click();
  await expect(page).toHaveURL(/status=resolved/);
  await page.getByRole("link", { name: "Corrections" }).click();
  await expect(page).toHaveURL(/kind=route_correction/);
  await page.getByPlaceholder("Route, gym, or keyword").fill(runToken);
  await page.getByRole("button", { name: "Search" }).click();
  await expect(page).toHaveURL(new RegExp(`q=${runToken}`));
});

test("dismisses a report and resolves it out of the pending queue", async ({ page }) => {
  await signIn(page);
  await openItem(page, `${runToken} dismiss`, "spam");
  await confirmDecision(page, "Dismiss", `Gate dismissal ${runToken}`);
  await expect(page).toHaveURL(/\/review\?status=pending/);
  await expect(page.getByText(`Gate flow ${runToken} dismiss`)).toBeHidden();
});

test("hides reported content and restores it", async ({ page }) => {
  const { url, key } = supabaseUrl();
  const guest = createClient(url, key, { auth: { persistSession: false } });
  await signIn(page);
  await openItem(page, `${runToken} hide`, "spam");
  await confirmDecision(page, "Hide", `Gate hide ${runToken}`);

  const { count: hiddenCount } = await guest
    .from("route_summaries")
    .select("id", { count: "exact", head: true })
    .eq("id", "30000000-0000-4000-8000-000000000003");
  expect(hiddenCount).toBe(0);

  await page.goto(`/review?status=resolved&q=${runToken}%20hide`);
  await page.getByRole("cell", { name: "spam", exact: true }).click();
  await expect(page.getByRole("dialog", { name: "Review details" })).toBeVisible();
  await confirmDecision(page, "Restore", `Gate restore ${runToken}`);

  const { count: restoredCount } = await guest
    .from("route_summaries")
    .select("id", { count: "exact", head: true })
    .eq("id", "30000000-0000-4000-8000-000000000003");
  expect(restoredCount).toBe(1);
});

test("accepts a correction as an Administrator", async ({ page }) => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  await signIn(page);
  await openItem(page, `${runToken} accept-admin`, "grade");
  await confirmDecision(page, "Accept", `Gate acceptance ${runToken}`);

  const { data } = await admin
    .from("route_corrections")
    .select("status,reviewed_by")
    .eq("route_id", "30000000-0000-4000-8000-000000000004")
    .order("created_at", { ascending: false })
    .limit(1)
    .single();
  expect(data?.status).toBe("accepted");
  expect(data?.reviewed_by).toBe("90000000-0000-4000-8000-000000000007");
});

test("a Moderator escalates but is not offered correction acceptance", async ({ page }) => {
  await signIn(page, "fixture-moderator@bloclens.invalid");
  await openItem(page, `${runToken} escalate`, "other");
  await expect(page.getByRole("button", { name: "Escalate", exact: true })).toBeVisible();
  await confirmDecision(page, "Escalate", `Gate escalation ${runToken}`);

  await openItem(page, `${runToken} accept-view`, "holds");
  await expect(
    page.getByRole("button", { name: "Accept", exact: true }),
  ).toBeHidden();
});

test("a stale inspector shows the conflict state instead of overwriting", async ({ page }) => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  await signIn(page);
  await openItem(page, `${runToken} conflict`, "spam");
  await page.getByRole("button", { name: "Dismiss", exact: true }).click();
  await expect(page.getByRole("dialog", { name: /Confirm review decision/ })).toBeVisible();
  await page.getByLabel(decisions.reasonLabel).fill(`Gate stale ${runToken}`);

  // A concurrent decision bumps the version before this dialog submits.
  const { data: item } = await admin
    .from("content_reports")
    .select("id")
    .ilike("details", `%${runToken} conflict%`)
    .single();
  await admin
    .from("content_reports")
    .update({ status: "under_review" })
    .eq("id", item?.id ?? "");

  await page.getByRole("button", { name: decisions.confirm }).click();
  await expect(page.getByText(decisions.conflictBody)).toBeVisible({ timeout: 10000 });
});

test("decisions leave an immutable audit trail", async () => {
  const admin = await sessionClient("fixture-admin@bloclens.invalid");
  const { data, error } = await admin
    .from("admin_audit_events")
    .select("action_key,outcome,after_summary")
    .eq("action_key", "review.decision")
    .order("created_at", { ascending: false })
    .limit(20);
  expect(error).toBeNull();
  const succeeded = (data ?? []).filter((row) => row.outcome === "succeeded");
  expect(succeeded.length).toBeGreaterThanOrEqual(4);
  expect(
    succeeded.some((row) => JSON.stringify(row.after_summary).includes("dismiss")),
  ).toBe(true);
});
