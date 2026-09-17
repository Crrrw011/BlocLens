import { beforeEach, describe, expect, it, vi } from "vitest";

import { setVisibility } from "./visibility-action";

const { rpc, revalidatePath } = vi.hoisted(() => ({
  rpc: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => ({ rpc }),
}));
vi.mock("next/cache", () => ({ revalidatePath }));

const ID = "98000000-0000-4000-8000-000000000004";
const KEY = "98000000-0000-4000-8000-000000000101";
const VERSION = "2026-09-15T00:00:00.000Z";

function visibilityForm(
  overrides: Partial<{
    kind: string;
    id: string;
    action: string;
    reason: string;
    expectedUpdatedAt: string;
    idempotencyKey: string;
  }> = {},
) {
  const data = new FormData();
  data.set("kind", "route_photo");
  data.set("id", ID);
  data.set("action", "archive");
  data.set("reason", "Blurry duplicate photo");
  data.set("expectedUpdatedAt", VERSION);
  data.set("idempotencyKey", KEY);
  for (const [key, value] of Object.entries(overrides)) data.set(key, value);
  return data;
}

describe("setVisibility", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("archives with reason, version, and idempotency key, then revalidates", async () => {
    const result = await setVisibility({ status: "idle" }, visibilityForm());
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledWith("admin_set_visibility", {
      entity_kind: "route_photo",
      entity_id: ID,
      action: "archive",
      reason: "Blurry duplicate photo",
      expected_updated_at: VERSION,
      idempotency_key: KEY,
    });
    expect(revalidatePath).toHaveBeenCalledWith("/climbing-data");
    expect(revalidatePath).toHaveBeenCalledWith("/overview");
  });

  it("rejects gyms, resets, unknown actions, and short reasons before any database call", async () => {
    for (const bad of [
      { kind: "gym" },
      { kind: "reset" },
      { action: "delete" },
      { reason: "  " },
      { id: "not-a-uuid" },
      { expectedUpdatedAt: "yesterday" },
    ]) {
      const result = await setVisibility({ status: "idle" }, visibilityForm(bad));
      expect(result.status).toBe("error");
    }
    expect(rpc).not.toHaveBeenCalled();
    expect(revalidatePath).not.toHaveBeenCalled();
  });

  it("maps stale versions to a conflict state", async () => {
    rpc.mockResolvedValue({ data: [{ ok: false, error_code: "conflict" }], error: null });
    const result = await setVisibility({ status: "idle" }, visibilityForm());
    expect(result.status).toBe("error");
    if (result.status === "error") {
      expect("conflict" in result).toBe(true);
    }
    expect(revalidatePath).not.toHaveBeenCalled();
  });

  it("maps denied transitions to the generic unavailable state", async () => {
    rpc.mockResolvedValue({ data: [{ ok: false, error_code: "forbidden" }], error: null });
    const result = await setVisibility({ status: "idle" }, visibilityForm());
    expect(result).toEqual({
      status: "error",
      message: "This change could not be recorded. Try again.",
    });
  });

  it("keeps the same idempotency key across a network retry", async () => {
    rpc.mockRejectedValueOnce(new Error("network down"));
    const first = await setVisibility({ status: "idle" }, visibilityForm());
    expect(first.status).toBe("error");

    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
    const second = await setVisibility(first, visibilityForm());
    expect(second).toEqual({ status: "success" });
    expect(rpc.mock.calls[1]?.[1]).toMatchObject({ idempotency_key: KEY });
  });
});
