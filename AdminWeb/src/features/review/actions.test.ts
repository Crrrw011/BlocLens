import { beforeEach, describe, expect, it, vi } from "vitest";

import { decideReview } from "./actions";

const { rpc, revalidatePath } = vi.hoisted(() => ({
  rpc: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => ({ rpc }),
}));
vi.mock("next/cache", () => ({ revalidatePath }));

function form(
  overrides: Partial<{
    kind: string;
    id: string;
    decision: string;
    reason: string;
    expectedUpdatedAt: string;
    idempotencyKey: string;
  }> = {},
) {
  const data = new FormData();
  data.set("kind", "content_report");
  data.set("id", "97000000-0000-4000-8000-000000000001");
  data.set("decision", "dismiss");
  data.set("reason", "Spam pattern confirmed");
  data.set("expectedUpdatedAt", "2026-09-15T00:00:00.000Z");
  data.set("idempotencyKey", "97000000-0000-4000-8000-000000000101");
  for (const [key, value] of Object.entries(overrides)) {
    if (value !== undefined) data.set(key, value);
  }
  return data;
}

describe("decideReview", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("records a valid decision and revalidates the affected routes", async () => {
    const result = await decideReview({ status: "idle" }, form());
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledWith("admin_decide_review", {
      item_kind: "content_report",
      item_id: "97000000-0000-4000-8000-000000000001",
      decision: "dismiss",
      reason: "Spam pattern confirmed",
      expected_updated_at: "2026-09-15T00:00:00.000Z",
      idempotency_key: "97000000-0000-4000-8000-000000000101",
    });
    expect(revalidatePath).toHaveBeenCalledWith("/overview");
    expect(revalidatePath).toHaveBeenCalledWith("/review");
  });

  it("accepts database timestamps with a numeric offset", async () => {
    const result = await decideReview(
      { status: "idle" },
      form({ expectedUpdatedAt: "2026-09-15T09:07:32.87412+00:00" }),
    );
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledOnce();
  });

  it("requires a reason, UUIDs, and a timestamp before any database call", async () => {
    for (const bad of [
      { reason: "  " },
      { id: "not-a-uuid" },
      { expectedUpdatedAt: "yesterday" },
      { idempotencyKey: "not-a-uuid" },
      { decision: "delete" },
    ]) {
      const result = await decideReview({ status: "idle" }, form(bad));
      expect(result.status).toBe("error");
    }
    expect(rpc).not.toHaveBeenCalled();
    expect(revalidatePath).not.toHaveBeenCalled();
  });

  it("maps stale versions to a conflict state", async () => {
    rpc.mockResolvedValue({ data: [{ ok: false, error_code: "conflict" }], error: null });
    const result = await decideReview({ status: "idle" }, form());
    expect(result.status).toBe("error");
    if (result.status === "error") {
      expect("conflict" in result).toBe(true);
    }
    expect(revalidatePath).not.toHaveBeenCalled();
  });

  it("keeps the same idempotency key across a network retry", async () => {
    rpc.mockRejectedValueOnce(new Error("network down"));
    const first = await decideReview({ status: "idle" }, form());
    expect(first.status).toBe("error");

    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
    const second = await decideReview(first, form());
    expect(second).toEqual({ status: "success" });
    expect(rpc.mock.calls[1]?.[1]).toMatchObject({
      idempotency_key: "97000000-0000-4000-8000-000000000101",
    });
  });
});
