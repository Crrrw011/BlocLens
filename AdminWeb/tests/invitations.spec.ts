import { expect, test } from "@playwright/test";
import { messages } from "../src/localization/messages";
import { createClient } from "@supabase/supabase-js";

test.describe.configure({ mode: "serial" });
const copy = messages.en.auth;
const password = "BlocLensInvitation1!";

async function signIn(page: import("@playwright/test").Page, email = "fixture-admin@bloclens.invalid") {
  await page.goto("/sign-in");
  await page.getByLabel(copy.signIn.emailLabel).fill(email);
  await page.getByLabel(copy.signIn.passwordLabel).fill("BlocLensLocalTest1!");
  await page.getByRole("button", { name: copy.signIn.submit }).click();
  await expect(page).toHaveURL(/\/overview$/);
}

async function invitationLink(email: string) {
  let link: string | undefined;
  await expect.poll(async () => {
    const mailbox = await (await fetch("http://127.0.0.1:54324/api/v1/messages?limit=100")).json();
    const mail = mailbox.messages.find((message: { To: { Address: string }[] }) => message.To.some(({ Address }) => Address === email));
    if (!mail) return false;
    const detail = await (await fetch(`http://127.0.0.1:54324/api/v1/message/${mail.ID}`)).json();
    link = detail.Text.match(/\(\s*(https?:\/\/[^\s)]+)\s*\)/)?.[1];
    return Boolean(link);
  }).toBe(true);
  if (!link) throw new Error("Invitation email did not contain a link");
  return link;
}

test("missing invitation shows a safe accessible recovery state", async ({ page }) => {
  await page.goto("/accept-invite");
  await expect(page.getByRole("heading", { name: "Join BlocLens Operations" })).toBeVisible();
  await expect(page.getByRole("alert").filter({ hasText: "Ask your administrator" })).toBeVisible();
  await expect(page.getByRole("button", { name: "Accept invitation" })).toBeDisabled();
});

test("invites a new Moderator through email, sets a password, and opens the protected overview", async ({ page, browser }) => {
  await signIn(page);
  const email = `invite-${crypto.randomUUID()}@bloclens.invalid`;
  const result = await page.request.post("/api/staff/invitations", {
    headers: { origin: "http://127.0.0.1:3000" },
    data: { email, role: "moderator", reason: "Local invitation integration verification" },
  });
  expect(result.status()).toBe(202);
  expect(await result.json()).toEqual({ status: "accepted" });
  const recipient = await browser.newContext();
  try {
    const acceptedPage = await recipient.newPage();
    await acceptedPage.goto(await invitationLink(email));
    await expect(acceptedPage.getByRole("button", { name: "Accept invitation" })).toBeEnabled();
    await expect(acceptedPage).toHaveURL(/\/accept-invite$/);
    await acceptedPage.getByLabel(copy.updatePassword.passwordLabel, { exact: true }).fill(password);
    await acceptedPage.getByLabel(copy.updatePassword.passwordConfirmationLabel).fill(password);
    await acceptedPage.getByRole("button", { name: "Accept invitation" }).click();
    await expect(acceptedPage).toHaveURL(/\/overview$/);
    await expect(acceptedPage.getByRole("heading", { name: "Overview" })).toBeVisible();
    await acceptedPage.getByRole("button", { name: messages.en.shell.accountMenu }).click();
    await acceptedPage.getByRole("menuitem", { name: copy.portal.signOut }).click();
    await acceptedPage.getByLabel(copy.signIn.emailLabel).fill(email);
    await acceptedPage.getByLabel(copy.signIn.passwordLabel).fill(password);
    await acceptedPage.getByRole("button", { name: copy.signIn.submit }).click();
    await expect(acceptedPage).toHaveURL(/\/overview$/);
  } finally {
    await recipient.close();
  }
});

test("Moderator and cross-origin requests cannot create staff invitations", async ({ page }) => {
  await signIn(page, "fixture-moderator@bloclens.invalid");
  const data = { email: "forbidden@bloclens.invalid", role: "moderator", reason: "Must be rejected" };
  expect((await page.request.post("/api/staff/invitations", { headers: { origin: "http://127.0.0.1:3000" }, data })).status()).toBe(403);
  expect((await page.request.post("/api/staff/invitations", { headers: { origin: "https://elsewhere.example" }, data })).status()).toBe(403);
});

test("invites an existing Auth account without disclosing account existence", async ({ page, browser }) => {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const secret = process.env.LOCAL_SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !secret) throw new Error("Local Supabase test credentials are required");
  const admin = createClient(url, secret, { auth: { persistSession: false, autoRefreshToken: false } });
  const email = `existing-invite-${crypto.randomUUID()}@bloclens.invalid`;
  const { error } = await admin.auth.admin.createUser({ email, password: "OriginalPassword1!", email_confirm: true });
  expect(error).toBeNull();
  await signIn(page);
  const result = await page.request.post("/api/staff/invitations", {
    headers: { origin: "http://127.0.0.1:3000" },
    data: { email, role: "moderator", reason: "Local existing-account invitation verification" },
  });
  expect(result.status()).toBe(202);
  expect(await result.json()).toEqual({ status: "accepted" });
  const recipient = await browser.newContext();
  try {
    const acceptedPage = await recipient.newPage();
    await acceptedPage.goto(await invitationLink(email));
    await expect(acceptedPage.getByRole("button", { name: "Accept invitation" })).toBeEnabled();
    await acceptedPage.getByLabel(copy.updatePassword.passwordLabel, { exact: true }).fill(password);
    await acceptedPage.getByLabel(copy.updatePassword.passwordConfirmationLabel).fill(password);
    await acceptedPage.getByRole("button", { name: "Accept invitation" }).click();
    await expect(acceptedPage).toHaveURL(/\/overview$/);
  } finally {
    await recipient.close();
  }
});

for (const colorScheme of ["light", "dark"] as const) {
  for (const width of [375, 430, 1440]) {
    test(`invitation layout is accessible at ${width}px in ${colorScheme}`, async ({ page }) => {
      await page.setViewportSize({ width, height: 932 });
      await page.emulateMedia({ colorScheme, reducedMotion: "reduce" });
      await page.goto("/accept-invite");
      await expect(page.getByRole("alert").filter({ hasText: "Ask your administrator" })).toBeVisible();
      await page.evaluate(() => { document.documentElement.style.fontSize = "200%"; });
      const field = page.getByLabel(copy.updatePassword.passwordLabel, { exact: true });
      await field.focus();
      await expect(field).toBeFocused();
      const size = await field.boundingBox();
      expect(size?.height).toBeGreaterThanOrEqual(44);
      expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
      await page.screenshot({ path: test.info().outputPath(`invitation-${colorScheme}-${width}.png`), fullPage: true });
    });
  }
}
