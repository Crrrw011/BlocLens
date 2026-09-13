import { afterEach, describe, expect, it, vi } from "vitest";

const originalAdminOrigin = process.env.ADMIN_ORIGIN;

function setAdminOrigin(value: string | undefined) {
  if (value === undefined) {
    delete process.env.ADMIN_ORIGIN;
  } else {
    process.env.ADMIN_ORIGIN = value;
  }
}

async function importAdminOrigin() {
  vi.resetModules();
  return import("./admin-origin");
}

afterEach(() => {
  setAdminOrigin(originalAdminOrigin);
  vi.resetModules();
});

describe("getAdminOrigin", () => {
  it("returns only the configured HTTP(S) origin", async () => {
    setAdminOrigin("https://admin.bloclens.example");
    const { getAdminOrigin } = await importAdminOrigin();

    expect(getAdminOrigin()).toBe("https://admin.bloclens.example");
  });

  it.each([
    "ftp://admin.bloclens.example",
    "https://user:password@admin.bloclens.example",
    "https://admin.bloclens.example/path",
    "https://admin.blocens.example?next=/update-password",
    "https://admin.bloclens.example/#fragment",
  ])("rejects a non-origin canonical admin URL: %s", async (adminOrigin) => {
    setAdminOrigin(adminOrigin);
    const { getAdminOrigin } = await importAdminOrigin();

    expect(() => getAdminOrigin()).toThrow(/ADMIN_ORIGIN/);
  });
});
