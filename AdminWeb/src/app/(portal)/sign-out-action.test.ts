import { beforeEach, describe, expect, it, vi } from "vitest";

const signOutSpy = vi.fn();

vi.mock("@/lib/supabase/server", () => ({
  createServerClient: vi.fn(async () => ({ auth: { signOut: signOutSpy } })),
}));

vi.mock("next/navigation", () => ({
  redirect: vi.fn((location: string): never => {
    throw new Error(`redirect:${location}`);
  }),
}));

describe("signOut", () => {
  beforeEach(() => {
    vi.resetModules();
    signOutSpy.mockReset();
  });

  it("ends only the local session before returning to sign-in", async () => {
    signOutSpy.mockResolvedValue({ error: null });
    const { signOut } = await import("./sign-out-action");

    await expect(signOut()).rejects.toThrow("redirect:/sign-in");
    expect(signOutSpy).toHaveBeenCalledWith({ scope: "local" });
  });
});
