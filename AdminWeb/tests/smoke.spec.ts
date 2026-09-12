import { expect, test } from "@playwright/test";

test("root redirects unauthenticated visitors to sign-in", async ({ page }) => {
  await page.goto("/");

  await expect(page).toHaveURL(/\/sign-in$/);
});
