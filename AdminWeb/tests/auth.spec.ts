import { expect, test } from "@playwright/test";

import { messages } from "../src/localization/messages";

const localPassword = "BlocLensLocalTest1!";

async function signIn(page: import("@playwright/test").Page, email: string) {
  await page.goto("/sign-in");
  await page.getByLabel(messages.en.auth.signIn.emailLabel).fill(email);
  await page.getByLabel(messages.en.auth.signIn.passwordLabel).fill(localPassword);
  await page.getByRole("button", { name: messages.en.auth.signIn.submit }).click();
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
  await page.getByRole("button", { name: messages.en.auth.portal.signOut }).click();

  await expect(page).toHaveURL(/\/sign-in$/);
});

test("sends authenticated non-staff users to access denied", async ({ page }) => {
  await signIn(page, "fixture-climber-1@bloclens.invalid");

  await expect(page).toHaveURL(/\/access-denied$/);
  await expect(
    page.getByRole("heading", { name: messages.en.auth.accessDenied.title }),
  ).toBeVisible();
});
