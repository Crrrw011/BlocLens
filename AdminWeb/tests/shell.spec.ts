import { expect, test } from "@playwright/test";

import { messages } from "../src/localization/messages";

const localPassword = "BlocLensLocalTest1!";
const viewports = [
  { name: "wide", width: 1440, height: 1000 },
  { name: "overlay", width: 1024, height: 768 },
  { name: "narrow", width: 390, height: 844 },
] as const;
const phoneReviewViewports = [
  { name: "se", width: 375, height: 667 },
  { name: "pro-max", width: 430, height: 932 },
] as const;

test.describe.configure({ mode: "serial" });

async function signIn(page: import("@playwright/test").Page, email: string) {
  await page.goto("/sign-in");
  await page.getByLabel(messages.en.auth.signIn.emailLabel).fill(email);
  await page.getByLabel(messages.en.auth.signIn.passwordLabel).fill(localPassword);
  await page.getByRole("button", { name: messages.en.auth.signIn.submit }).click();
  await expect(page).toHaveURL(/\/overview$/);
}

for (const viewport of viewports) {
  test(`renders the reduced-motion shell at ${viewport.width}x${viewport.height}`, async ({
    page,
  }, testInfo) => {
    await page.setViewportSize(viewport);
    await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "light" });
    await signIn(page, "fixture-admin@bloclens.invalid");

    await expect(page.getByRole("navigation", { name: messages.en.shell.primaryNavigation })).toBeVisible();
    await expect(page.getByRole("link", { name: messages.en.shell.destinations.overview })).toHaveAttribute(
      "aria-current",
      "page",
    );
    await expect(page.getByRole("button", { name: messages.en.shell.notifications })).toBeVisible();
    await expect(page.getByRole("button", { name: messages.en.shell.accountMenu })).toBeVisible();
    await expect(page.getByRole("heading", { name: messages.en.auth.portal.title })).toBeVisible();

    const railWidth = await page
      .getByRole("navigation", { name: messages.en.shell.primaryNavigation })
      .evaluate((element) => element.getBoundingClientRect().width);
    expect(railWidth).toBe(64);

    const workspaceTransition = await page
      .locator(".app-shell__workspace")
      .evaluate((element) => getComputedStyle(element).transitionDuration);
    expect(Number.parseFloat(workspaceTransition)).toBeLessThanOrEqual(0.00001);

    await page.keyboard.press("Meta+k");
    const search = page.getByRole("searchbox", { name: messages.en.shell.search.label });
    await expect(search).toBeFocused();
    const focusOutline = await search.evaluate((element) => {
      const style = getComputedStyle(element);
      return { style: style.outlineStyle, width: style.outlineWidth };
    });
    expect(focusOutline.style).not.toBe("none");
    expect(focusOutline.width).toBe("3px");

    const overflowsHorizontally = await page.evaluate(
      () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
    );
    expect(overflowsHorizontally).toBe(false);

    await page.screenshot({
      path: testInfo.outputPath(`shell-${viewport.name}-${viewport.width}x${viewport.height}.png`),
      fullPage: true,
    });
  });
}

for (const viewport of [viewports[0], viewports[2]]) {
  test(`renders the dark shell at ${viewport.width}x${viewport.height}`, async ({
    page,
  }, testInfo) => {
    await page.setViewportSize(viewport);
    await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "dark" });
    await signIn(page, "fixture-admin@bloclens.invalid");

    await expect(page.getByRole("heading", { name: messages.en.auth.portal.title })).toBeVisible();
    await expect(page.getByRole("searchbox", { name: messages.en.shell.search.label })).toBeVisible();
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
      ),
    ).toBe(false);

    await page.screenshot({
      path: testInfo.outputPath(`shell-dark-${viewport.width}x${viewport.height}.png`),
      fullPage: true,
    });
  });
}

for (const viewport of phoneReviewViewports) {
  test(`keeps the shell usable at the ${viewport.name} review size`, async ({ page }, testInfo) => {
    await page.setViewportSize(viewport);
    await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "light" });
    await signIn(page, "fixture-admin@bloclens.invalid");

    await expect(page.getByRole("heading", { name: messages.en.auth.portal.title })).toBeVisible();
    await expect(page.getByRole("searchbox", { name: messages.en.shell.search.label })).toBeVisible();
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
      ),
    ).toBe(false);

    await page.screenshot({
      path: testInfo.outputPath(`shell-${viewport.name}-${viewport.width}x${viewport.height}.png`),
      fullPage: true,
    });
  });
}

test("preserves visible focus in forced-colours mode", async ({ page }) => {
  await page.setViewportSize(viewports[2]);
  await page.emulateMedia({ forcedColors: "active", reducedMotion: "reduce" });
  await signIn(page, "fixture-admin@bloclens.invalid");

  await page.keyboard.press("Meta+k");
  const search = page.getByRole("searchbox", { name: messages.en.shell.search.label });
  await expect(search).toBeFocused();
  await expect(search).toHaveCSS("outline-style", "solid");
});

test("keeps Administrator-only destinations out of the Moderator shell", async ({ page }) => {
  await signIn(page, "fixture-moderator@bloclens.invalid");

  await expect(
    page.getByRole("link", { name: messages.en.shell.destinations.peopleAccess }),
  ).toHaveCount(0);
  await expect(
    page.getByRole("link", { name: messages.en.shell.destinations.configuration }),
  ).toHaveCount(0);
  await expect(page.getByRole("link", { name: messages.en.shell.destinations.review })).toBeVisible();
});
