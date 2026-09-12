import { beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

const createBrowserClientSpy = vi.fn();

vi.mock("@supabase/ssr", () => ({
  createBrowserClient: createBrowserClientSpy,
}));

beforeAll(() => {
  vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321");
  vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "local-publishable-key");
});

describe("parsePublicEnvironment", () => {
  it("accepts a Supabase URL and publishable key", async () => {
    const { parsePublicEnvironment } = await import("./env");

    expect(
      parsePublicEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "local-publishable-key",
      }),
    ).toEqual({
      NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "local-publishable-key",
    });
  });

  it("rejects a missing Supabase URL", async () => {
    const { parsePublicEnvironment } = await import("./env");

    expect(() =>
      parsePublicEnvironment({
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "local-publishable-key",
      }),
    ).toThrow(/NEXT_PUBLIC_SUPABASE_URL/);
  });

  it("rejects a missing Supabase publishable key", async () => {
    const { parsePublicEnvironment } = await import("./env");

    expect(() =>
      parsePublicEnvironment({
        NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
      }),
    ).toThrow(/NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY/);
  });
});

describe("createBrowserClient", () => {
  beforeEach(() => {
    createBrowserClientSpy.mockReset();
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "http://127.0.0.1:54321");
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "local-publishable-key");
    vi.resetModules();
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
