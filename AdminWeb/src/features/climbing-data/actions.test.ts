import { beforeEach, describe, expect, it, vi } from "vitest";

import { changeLifecycle, updateEntity } from "./actions";

const { rpc, revalidatePath } = vi.hoisted(() => ({
  rpc: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => ({ rpc }),
}));
vi.mock("next/cache", () => ({ revalidatePath }));

const ID = "98000000-0000-4000-8000-000000000003";
const KEY = "98000000-0000-4000-8000-000000000101";
const VERSION = "2026-09-15T00:00:00.000Z";

function updateForm(
  overrides: Partial<{
    colour: string;
    gym_grade: string;
    terrain: string;
    subjective_grade: string;
    id: string;
    reason: string;
    expectedUpdatedAt: string;
    idempotencyKey: string;
  }> = {},
) {
  const data = new FormData();
  data.set("kind", "route");
  data.set("id", ID);
  data.set("colour", "Cyan");
  data.set("gym_grade", "4");
  data.set("terrain", "overhang");
  data.set("subjective_grade", "");
  data.set("reason", "Colour verified against the wall");
  data.set("expectedUpdatedAt", VERSION);
  data.set("idempotencyKey", KEY);
  for (const [key, value] of Object.entries(overrides)) data.set(key, value);
  return data;
}

function lifecycleForm(
  overrides: Partial<{ routeId: string; action: string; reason: string; expectedUpdatedAt: string; idempotencyKey: string }> = {},
) {
  const data = new FormData();
  data.set("routeId", ID);
  data.set("action", "archive");
  data.set("reason", "Route retired after reset");
  data.set("expectedUpdatedAt", VERSION);
  data.set("idempotencyKey", KEY);
  for (const [key, value] of Object.entries(overrides)) data.set(key, value);
  return data;
}

describe("updateEntity", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("sends a whitelisted patch and revalidates the workspace", async () => {
    const result = await updateEntity({ status: "idle" }, updateForm());
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledWith("admin_update_entity", {
      entity_kind: "route",
      entity_id: ID,
      patch: { colour: "Cyan", gym_grade: 4, terrain: "overhang" },
      reason: "Colour verified against the wall",
      expected_updated_at: VERSION,
      idempotency_key: KEY,
    });
    expect(revalidatePath).toHaveBeenCalledWith("/climbing-data");
  });

  it("requires valid fields and a reason before any database call", async () => {
    for (const bad of [
      { colour: "  " },
      { gym_grade: "99" },
      { terrain: "moon" },
      { id: "not-a-uuid" },
      { reason: "" },
      { expectedUpdatedAt: "yesterday" },
    ]) {
      const result = await updateEntity({ status: "idle" }, updateForm(bad));
      expect(result.status).toBe("error");
    }
    expect(rpc).not.toHaveBeenCalled();
  });

  it("accepts database timestamps with a numeric offset", async () => {
    const result = await updateEntity(
      { status: "idle" },
      updateForm({ expectedUpdatedAt: "2026-09-15T09:07:32.87412+00:00" }),
    );
    expect(result).toEqual({ status: "success" });
  });

  it("maps stale versions to a conflict state", async () => {
    rpc.mockResolvedValue({ data: [{ ok: false, error_code: "conflict" }], error: null });
    const result = await updateEntity({ status: "idle" }, updateForm());
    expect(result.status).toBe("error");
    if (result.status === "error") expect("conflict" in result).toBe(true);
    expect(revalidatePath).not.toHaveBeenCalled();
  });

  it("retains the same idempotency key across a network retry", async () => {
    rpc.mockResolvedValueOnce({ data: null, error: { message: "down" } });
    const first = await updateEntity({ status: "idle" }, updateForm());
    expect(first.status).toBe("error");

    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
    const second = await updateEntity(first, updateForm());
    expect(second).toEqual({ status: "success" });
    expect(rpc.mock.calls[1]?.[1]).toMatchObject({ idempotency_key: KEY });
  });
});

describe("changeLifecycle", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("records a lifecycle change and revalidates affected routes", async () => {
    const result = await changeLifecycle({ status: "idle" }, lifecycleForm());
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledWith("admin_change_lifecycle", {
      route_id: ID,
      action: "archive",
      reason: "Route retired after reset",
      expected_updated_at: VERSION,
      idempotency_key: KEY,
    });
    expect(revalidatePath).toHaveBeenCalledWith("/climbing-data");
    expect(revalidatePath).toHaveBeenCalledWith("/overview");
    expect(revalidatePath).toHaveBeenCalledWith("/review");
  });

  it("rejects unknown actions before any database call", async () => {
    const result = await changeLifecycle(
      { status: "idle" },
      lifecycleForm({ action: "delete" }),
    );
    expect(result.status).toBe("error");
    expect(rpc).not.toHaveBeenCalled();
  });
});
