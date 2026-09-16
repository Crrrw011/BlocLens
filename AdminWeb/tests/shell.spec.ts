import { expect, test, type Page } from "@playwright/test";

import { messages } from "../src/localization/messages";

const localPassword = "BlocLensLocalTest1!";
const harnessPath = "/test-harness/shell";
const harness = {
  title: "Shell component review",
  openInspector: "Open review details",
  inspectorTitle: "Review details",
  openDecision: "Open review decision",
  decisionTitle: "Review decision",
  batchAction: "Resolve selected reports",
  tableCaption: "Review queue samples",
  firstRow: "Route report",
} as const;

test.describe.configure({ mode: "serial" });

async function signIn(page: Page, email = "fixture-admin@bloclens.invalid") {
  await page.goto("/sign-in");
  await page.getByLabel(messages.en.auth.signIn.emailLabel).fill(email);
  await page.getByLabel(messages.en.auth.signIn.passwordLabel).fill(localPassword);
  await page.getByRole("button", { name: messages.en.auth.signIn.submit }).click();
  await expect(page).toHaveURL(/\/overview$/);
}

async function openHarness(page: Page) {
  await signIn(page);
  await page.goto(harnessPath);
  await expect(page.getByRole("heading", { name: harness.title })).toBeVisible();
  await expect(page.getByRole("table", { name: harness.tableCaption })).toBeVisible();
  await expect(page.getByText(harness.firstRow, { exact: true })).toBeVisible();
}

test("renders a populated reduced-motion shell and a nonmodal 360px Inspector at 1440", async ({
  page,
}, testInfo) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "light" });
  await openHarness(page);

  await page.getByRole("button", { name: harness.openInspector }).click();
  const inspector = page.getByRole("dialog", { name: harness.inspectorTitle });
  await expect(inspector).toBeVisible();
  expect(await inspector.evaluate((element) => element.getBoundingClientRect().width)).toBe(360);
  await expect(page.locator(".app-shell")).not.toHaveAttribute("inert", "");

  const search = page.getByRole("searchbox", { name: messages.en.shell.search.label });
  await search.focus();
  await expect(search).toBeFocused();
  await expect(inspector).toBeVisible();
  const workspace = page.locator(".app-shell__workspace");
  await expect(workspace).toHaveCSS("margin-right", "360px");
  expect(
    Number.parseFloat(
      await workspace.evaluate(
        (element) => getComputedStyle(element).transitionDuration,
      ),
    ),
  ).toBeLessThanOrEqual(0.00001);

  await expect(page.getByTestId("primary-button")).toHaveCSS("border-radius", "999px");
  await expect(page.getByTestId("secondary-button")).toHaveCSS("border-radius", "999px");
  await expect(page.getByTestId("destructive-button")).toHaveCSS("border-radius", "999px");

  await page.screenshot({
    path: testInfo.outputPath("shell-populated-wide-1440x1000.png"),
    fullPage: true,
  });
});

test("traps focus and makes the shell inert while the Inspector overlays at 1024", async ({
  page,
}, testInfo) => {
  await page.setViewportSize({ width: 1024, height: 768 });
  await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "light" });
  await openHarness(page);

  const opener = page.getByRole("button", { name: harness.openInspector });
  await opener.click();
  const inspector = page.getByRole("dialog", { name: harness.inspectorTitle });
  await expect(inspector).toBeVisible();
  await expect(page.locator(".app-shell")).toHaveAttribute("inert", "");
  expect(await inspector.evaluate((element) => element.getBoundingClientRect().width)).toBe(360);

  for (let press = 0; press < 6; press += 1) {
    await page.keyboard.press("Tab");
    expect(await inspector.locator(":focus").count()).toBe(1);
  }

  await page.locator(".page-header__search input").evaluate((element) => element.focus());
  await expect(page.locator(".page-header__search input")).not.toBeFocused();

  await page.screenshot({
    path: testInfo.outputPath("shell-populated-overlay-open-1024x768.png"),
    fullPage: true,
  });

  await page.keyboard.press("Escape");
  await expect(inspector).toHaveCount(0);
  await expect(opener).toBeFocused();
  await expect(page.locator(".app-shell")).not.toHaveAttribute("inert", "");

});

test("Escape closes only the top-layer Dialog before the overlay Inspector", async ({ page }) => {
  await page.setViewportSize({ width: 1024, height: 768 });
  await openHarness(page);

  await page.getByRole("button", { name: harness.openInspector }).click();
  const inspector = page.getByRole("dialog", { name: harness.inspectorTitle });
  await inspector.getByRole("button", { name: harness.openDecision }).click();
  const decision = page.getByRole("dialog", { name: harness.decisionTitle });
  await expect(decision).toBeVisible();

  await page.keyboard.press("Escape");
  await expect(decision).toHaveCount(0);
  await expect(inspector).toBeVisible();

  await page.keyboard.press("Escape");
  await expect(inspector).toHaveCount(0);
});

test("keeps the populated table horizontally scrollable from 768 through 1023", async ({ page }) => {
  await page.setViewportSize({ width: 900, height: 768 });
  await openHarness(page);

  const viewport = page.locator(".data-table__viewport");
  const dimensions = await viewport.evaluate((element) => ({
    clientWidth: element.clientWidth,
    scrollWidth: element.scrollWidth,
  }));
  expect(dimensions.scrollWidth).toBeGreaterThan(dimensions.clientWidth);
  await viewport.evaluate((element) => {
    element.scrollLeft = element.scrollWidth;
  });
  expect(await viewport.evaluate((element) => element.scrollLeft)).toBeGreaterThan(0);
});

test("uses single-item table mode and removes complex batch actions below 768", async ({
  page,
}, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "light" });
  await openHarness(page);

  await expect(page.getByText(messages.en.shell.narrowMode)).toBeVisible();
  await expect(page.getByRole("columnheader", { name: "Item" })).toBeVisible();
  await expect(page.getByRole("columnheader", { name: "Area" })).toBeVisible();
  await expect(page.getByRole("columnheader", { name: "Status" })).not.toBeVisible();
  await expect(page.getByRole("button", { name: harness.batchAction })).not.toBeVisible();
  expect(
    await page.locator(".data-table__viewport").evaluate(
      (element) => element.scrollWidth === element.clientWidth,
    ),
  ).toBe(true);

  await page.screenshot({
    path: testInfo.outputPath("shell-populated-narrow-390x844.png"),
    fullPage: true,
  });
});

for (const viewport of [
  { name: "wide", width: 1440, height: 1000 },
  { name: "narrow", width: 390, height: 844 },
] as const) {
  test(`renders the populated dark shell at ${viewport.width}x${viewport.height}`, async ({
    page,
  }, testInfo) => {
    await page.setViewportSize(viewport);
    await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "dark" });
    await openHarness(page);
    await expect(page.getByRole("button", { name: harness.openInspector })).toBeVisible();
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
      ),
    ).toBe(false);

    await page.screenshot({
      path: testInfo.outputPath(`shell-populated-dark-${viewport.name}.png`),
      fullPage: true,
    });
  });
}

for (const viewport of [
  { name: "se", width: 375, height: 667 },
  { name: "pro-max", width: 430, height: 932 },
] as const) {
  test(`keeps populated shell copy usable at the ${viewport.name} review size`, async ({ page }) => {
    await page.setViewportSize(viewport);
    await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "light" });
    await openHarness(page);
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth > document.documentElement.clientWidth,
      ),
    ).toBe(false);
  });
}

test("preserves visible focus in forced-colours mode", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ forcedColors: "active", reducedMotion: "reduce" });
  await openHarness(page);

  await page.keyboard.press("Meta+k");
  const search = page.getByRole("searchbox", { name: messages.en.shell.search.label });
  await expect(search).toBeFocused();
  await expect(search).toHaveCSS("outline-style", "solid");
});

test("wraps meaningful shell copy without clipping at 200 percent layout zoom", async ({ page }) => {
  await page.setViewportSize({ width: 1024, height: 768 });
  await page.emulateMedia({ reducedMotion: "reduce", colorScheme: "light" });
  await openHarness(page);
  await page.evaluate(() => {
    document.documentElement.style.zoom = "2";
  });
  // Webfont swap changes glyph metrics mid-measurement at this zoom.
  await page.evaluate(() => document.fonts.ready.then(() => true));

  for (const locator of [
    page.getByRole("heading", { name: harness.title }),
    page.getByRole("button", { name: harness.openInspector }),
  ]) {
    await expect(locator).toBeVisible();
    expect(
      await locator.evaluate(
        (element) =>
          element.scrollWidth <= element.clientWidth && element.scrollHeight <= element.clientHeight,
      ),
    ).toBe(true);
  }
  // Table cells truncate by design (nowrap + ellipsis); assert the
  // truncation is indicated, never a raw cut-off.
  const cell = page.getByText(harness.firstRow, { exact: true });
  await expect(cell).toBeVisible();
  expect(
    await cell.evaluate((element) => {
      const style = getComputedStyle(element);
      const fits =
        element.scrollWidth <= element.clientWidth &&
        element.scrollHeight <= element.clientHeight;
      const ellipsized =
        style.whiteSpace === "nowrap" &&
        style.overflow === "hidden" &&
        style.textOverflow === "ellipsis";
      return fits || ellipsized;
    }),
  ).toBe(true);
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
