import { createClient } from "@supabase/supabase-js";
import { expect, test } from "@playwright/test";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

import { messages } from "../src/localization/messages";

const localPassword = "BlocLensLocalTest1!";
const moderatorUserId = "90000000-0000-4000-8000-000000000006";
const localSupabaseURL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const localServiceRoleKey = process.env.LOCAL_SUPABASE_SERVICE_ROLE_KEY;
const execFileAsync = promisify(execFile);

test.describe.configure({ mode: "serial" });

function requireLocalServiceRoleKey() {
  if (!localSupabaseURL || !localServiceRoleKey) {
    throw new Error("Local Supabase URL and service role key are required for this test.");
  }

  return { localSupabaseURL, localServiceRoleKey };
}

async function setModeratorRevocation(revokedAt: string | null) {
  const timestamp = revokedAt === null ? "null" : `'${revokedAt}'::timestamptz`;
  await execFileAsync("docker", [
    "exec",
    "supabase_db_BlocLens",
    "psql",
    "-U",
    "postgres",
    "-d",
    "postgres",
    "-v",
    "ON_ERROR_STOP=1",
    "-c",
    `update public.app_user_roles set revoked_at = ${timestamp} where user_id = '${moderatorUserId}' and role = 'moderator';`,
  ]);
}

async function signIn(
  page: import("@playwright/test").Page,
  email: string,
  password = localPassword,
) {
  await page.goto("/sign-in");
  await page.getByLabel(messages.en.auth.signIn.emailLabel).fill(email);
  await page.getByLabel(messages.en.auth.signIn.passwordLabel).fill(password);
  await page.getByRole("button", { name: messages.en.auth.signIn.submit }).click();
}

type MailpitMessage = {
  ID: string;
  To: Array<{ Address: string }>;
};

type MailpitMessageDetail = {
  Text: string;
};

async function waitForRecoveryLink(email: string) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const messagesResponse = await fetch("http://127.0.0.1:54324/api/v1/messages?limit=100");
    const mailbox = (await messagesResponse.json()) as { messages: MailpitMessage[] };
    const message = mailbox.messages.find(({ To }) =>
      To.some(({ Address }) => Address === email),
    );

    if (message) {
      const detailResponse = await fetch(
        `http://127.0.0.1:54324/api/v1/message/${message.ID}`,
      );
      const detail = (await detailResponse.json()) as MailpitMessageDetail;
      const recoveryLink = detail.Text.match(/\(\s*(https?:\/\/[^\s)]+)\s*\)/)?.[1];

      if (recoveryLink) {
        return recoveryLink;
      }
    }

    await new Promise((resolve) => setTimeout(resolve, 250));
  }

  throw new Error(`Mailpit did not receive a recovery link for ${email}.`);
}

test("restores an active Administrator session on the sign-in route", async ({ page }) => {
  await signIn(page, "fixture-admin@bloclens.invalid");

  await expect(page).toHaveURL(/\/overview$/);
  await page.goto("/sign-in");
  await expect(page).toHaveURL(/\/overview$/);
});

test("allows active staff through the protected overview", async ({ page }) => {
  await signIn(page, "fixture-moderator@bloclens.invalid");

  await expect(page).toHaveURL(/\/overview$/);
  await expect(page.getByRole("heading", { name: messages.en.auth.portal.title })).toBeVisible();
});

test("does not reveal whether a password reset email exists", async ({ page }) => {
  await page.goto("/forgot-password");
  await page
    .getByLabel(messages.en.auth.forgotPassword.emailLabel)
    .fill("fixture-admin@bloclens.invalid");
  await page.getByRole("button", { name: messages.en.auth.forgotPassword.submit }).click();

  await expect(
    page.getByText(messages.en.auth.forgotPassword.success),
  ).toBeVisible();
});

test("signs out only the browser session", async ({ page }) => {
  await signIn(page, "fixture-admin@bloclens.invalid");
  await page.getByRole("button", { name: messages.en.shell.accountMenu }).click();
  await page.getByRole("menuitem", { name: messages.en.auth.portal.signOut }).click();

  await expect(page).toHaveURL(/\/sign-in$/);
});

test("sends authenticated non-staff users to access denied", async ({ page }) => {
  await signIn(page, "fixture-climber-1@bloclens.invalid");

  await expect(page).toHaveURL(/\/access-denied$/);
  await expect(
    page.getByRole("heading", { name: messages.en.auth.accessDenied.title }),
  ).toBeVisible();
});

test("does not expose public registration from the portal", async ({ page }) => {
  await page.goto("/sign-in");

  await expect(page.getByRole("link", { name: /sign up/i })).toHaveCount(0);
  await expect(page.getByRole("button", { name: /sign up/i })).toHaveCount(0);
});

test("denies a revoked Moderator partial RSC request without returning overview data", async ({ page }) => {
  test.skip(!localSupabaseURL || !localServiceRoleKey, "requires local Supabase service credentials");
  await signIn(page, "fixture-moderator@bloclens.invalid");
  await expect(page).toHaveURL(/\/overview$/);

  await setModeratorRevocation(new Date().toISOString());

  try {
    const response = await page.evaluate(async () => {
      const routerState = [
        "",
        {
          children: ["(portal)", { children: ["overview", { children: ["__PAGE__", {}] }] }],
        },
        null,
        null,
        true,
      ];
      const result = await fetch("/overview?__rsc=revoked-staff", {
        headers: {
          RSC: "1",
          "Next-Router-State-Tree": encodeURIComponent(JSON.stringify(routerState)),
        },
      });

      return {
        contentType: result.headers.get("content-type"),
        body: await result.text(),
      };
    });

    expect(response.contentType).toContain("text/x-component");
    expect(response.body).toContain("/access-denied");
    expect(response.body).not.toContain(messages.en.auth.portal.title);
  } finally {
    await setModeratorRevocation(null);
  }
});

test("completes recovery from Mailpit with a disposable local Auth user", async ({ page }) => {
  test.skip(!localSupabaseURL || !localServiceRoleKey, "requires local Supabase service credentials");
  test.setTimeout(30_000);

  const { localSupabaseURL: supabaseURL, localServiceRoleKey: serviceRoleKey } =
    requireLocalServiceRoleKey();
  const recoveryEmail = `recovery-${crypto.randomUUID()}@bloclens.invalid`;
  const initialPassword = "BlocLensRecoveryStart1!";
  const recoveredPassword = "BlocLensRecoveryFinish1!";
  const serviceClient = createClient(supabaseURL, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: createdUser, error: createUserError } = await serviceClient.auth.admin.createUser({
    email: recoveryEmail,
    password: initialPassword,
    email_confirm: true,
  });

  if (createUserError || !createdUser.user) {
    throw new Error(`Unable to create disposable recovery user: ${createUserError?.message}`);
  }

  try {
    await page.goto("/forgot-password");
    await page.getByLabel(messages.en.auth.forgotPassword.emailLabel).fill(recoveryEmail);
    await page.getByRole("button", { name: messages.en.auth.forgotPassword.submit }).click();
    await expect(page.getByText(messages.en.auth.forgotPassword.success)).toBeVisible();

    await page.goto(await waitForRecoveryLink(recoveryEmail));
    await expect(
      page.getByRole("heading", { name: messages.en.auth.updatePassword.title }),
    ).toBeVisible();
    await page
      .getByLabel(messages.en.auth.updatePassword.passwordLabel, { exact: true })
      .fill(recoveredPassword);
    await page
      .getByLabel(messages.en.auth.updatePassword.passwordConfirmationLabel)
      .fill(recoveredPassword);
    await page.getByRole("button", { name: messages.en.auth.updatePassword.submit }).click();
    await expect(page).toHaveURL(/\/access-denied$/);

    await page.getByRole("button", { name: messages.en.auth.accessDenied.signOut }).click();
    await expect(page).toHaveURL(/\/sign-in$/);
    await signIn(page, recoveryEmail, recoveredPassword);
    await expect(page).toHaveURL(/\/access-denied$/);
  } finally {
    const { error: deleteUserError } = await serviceClient.auth.admin.deleteUser(createdUser.user.id);

    if (deleteUserError) {
      throw new Error(`Unable to delete disposable recovery user: ${deleteUserError.message}`);
    }
  }
});
