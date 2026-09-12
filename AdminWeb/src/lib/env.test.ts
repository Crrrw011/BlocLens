import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

const createBrowserClientSpy = vi.fn();
const originalSupabaseURL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const originalSupabasePublishableKey =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

vi.mock("@supabase/ssr", () => ({
  createBrowserClient: createBrowserClientSpy,
}));

function setPublicEnvironment(
  url: string | undefined,
  publishableKey: string | undefined,
) {
  if (url === undefined) {
    delete process.env.NEXT_PUBLIC_SUPABASE_URL;
  } else {
    process.env.NEXT_PUBLIC_SUPABASE_URL = url;
  }

  if (publishableKey === undefined) {
    delete process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  } else {
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY = publishableKey;
  }
}

function restorePublicEnvironment() {
  setPublicEnvironment(originalSupabaseURL, originalSupabasePublishableKey);
}

async function importEnvironment() {
  vi.resetModules();
  return import("./env");
}

afterEach(() => {
  restorePublicEnvironment();
  vi.resetModules();
});

describe("env", () => {
  it("exports only the parsed environment", async () => {
    setPublicEnvironment("http://127.0.0.1:54321", "local-publishable-key");

    const environment = await importEnvironment();

    expect(Object.keys(environment)).toEqual(["env"]);
  });

  it("accepts a Supabase URL and publishable key", async () => {
    setPublicEnvironment("http://127.0.0.1:54321", "local-publishable-key");

    const { env } = await importEnvironment();

    expect(env).toEqual({
      NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "local-publishable-key",
    });
  });

  it("rejects a missing Supabase URL", async () => {
    setPublicEnvironment(undefined, "local-publishable-key");

    await expect(importEnvironment()).rejects.toThrow(/NEXT_PUBLIC_SUPABASE_URL/);
  });

  it("rejects a missing Supabase publishable key", async () => {
    setPublicEnvironment("http://127.0.0.1:54321", undefined);

    await expect(importEnvironment()).rejects.toThrow(
      /NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY/,
    );
  });
});

describe("createBrowserClient", () => {
  beforeEach(() => {
    createBrowserClientSpy.mockReset();
    setPublicEnvironment("http://127.0.0.1:54321", "local-publishable-key");
  });

  it("uses only validated public configuration", async () => {
    const browser = await import("./supabase/browser");

    browser.createBrowserClient();

    expect(createBrowserClientSpy).toHaveBeenCalledWith(
      "http://127.0.0.1:54321",
      "local-publishable-key",
    );
    expect(Object.keys(browser)).toEqual(["createBrowserClient"]);
  });
});
