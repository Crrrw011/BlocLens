import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests",
  // Outside the watched tree when set, so artifact writes never trigger
  // the dev server recompile that corrupts the production build under test.
  outputDir: process.env.PLAYWRIGHT_OUTPUT_DIR ?? "./test-results",
  fullyParallel: true,
  // Local auth fixtures are shared across suites, so session-mutating flows must not race.
  workers: 1,
  use: {
    baseURL: "http://127.0.0.1:3000",
    trace: "on-first-retry",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    command: "npm run build && npm run start",
    env: { PLAYWRIGHT_TEST_HARNESS: "1" },
    url: "http://127.0.0.1:3000",
    reuseExistingServer: !process.env.CI,
  },
});
