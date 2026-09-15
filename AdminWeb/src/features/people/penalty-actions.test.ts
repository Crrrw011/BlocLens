import { beforeEach, describe, expect, it, vi } from "vitest";

import { applyPenalty, reversePenalty } from "./penalty-actions";
import { getUserSummary } from "./repository";

const { rpc, revalidatePath } = vi.hoisted(() => ({
  rpc: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => ({ rpc }),
}));
vi.mock("next/cache", () => ({ revalidatePath }));

const USER = "90000000-0000-4000-8000-000000000001";
const KEY = "98000000-0000-4000-8000-000000000001";

function summaryRow(overrides: Record<string, unknown> = {}) {
  return {
    user_id: USER,
    username: "Fixture Climber One",
    member_since: "2026-08-20T00:00:00.000Z",
    staff_role: null,
    active_restrictions: [],
    recent_actions: [],
    contribution_counts: { routes: 1 },
    ...overrides,
  };
}

describe("getUserSummary", () => {
  it("maps public summaries without private content", async () => {
    rpc.mockReset().mockResolvedValue({ data: [summaryRow()], error: null });
    const result = await getUserSummary(USER, rpc);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.username).toBe("Fixture Climber One");
      expect(result.value.contributionCounts).toEqual({ routes: 1 });
    }
  });

  it("rejects invalid ids and maps denial to not_found", async () => {
    rpc.mockReset();
    const invalid = await getUserSummary("nope", rpc);
    expect(invalid.ok).toBe(false);
    expect(rpc).not.toHaveBeenCalled();

    rpc.mockResolvedValue({ data: [], error: null });
    const denied = await getUserSummary(USER, rpc);
    expect(denied.ok).toBe(false);
    if (!denied.ok) expect(denied.error.code).toBe("not_found");
  });
});

function applyForm(overrides: Record<string, string> = {}) {
  const data = new FormData();
  data.set("userId", USER);
  data.set("kind", "timed_suspension");
  data.set("endsAt", "2026-10-15T00:00:00.000Z");
  data.set("reason", "Harassment in comments");
  data.set("idempotencyKey", KEY);
  for (const [key, value] of Object.entries(overrides)) data.set(key, value);
  return data;
}

describe("applyPenalty", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("applies a suspension and revalidates people views", async () => {
    const result = await applyPenalty({ status: "idle" }, applyForm());
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledWith("admin_apply_user_penalty", {
      target_user_id: USER,
      penalty_kind: "timed_suspension",
      ends_at: "2026-10-15T00:00:00.000Z",
      reason: "Harassment in comments",
      idempotency_key: KEY,
    });
    expect(revalidatePath).toHaveBeenCalledWith("/people");
  });

  it("requires an end date for suspensions before any database call", async () => {
    const noEnd = await applyPenalty({ status: "idle" }, applyForm({ endsAt: "" }));
    expect(noEnd.status).toBe("error");
    expect(rpc).not.toHaveBeenCalled();
  });

  it("maps duplicate penalties distinctly", async () => {
    rpc.mockResolvedValue({ data: [{ ok: false, error_code: "already_active" }], error: null });
    const result = await applyPenalty({ status: "idle" }, applyForm());
    expect(result.status).toBe("error");
    if (result.status === "error") {
      expect(result.message).toContain("already active");
    }
  });
});

describe("reversePenalty", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("reverses a penalty with a reason", async () => {
    const data = new FormData();
    data.set("actionId", "96000000-0000-4000-8000-000000000041");
    data.set("reason", "Appeal upheld with a warning");
    data.set("idempotencyKey", KEY);
    const result = await reversePenalty({ status: "idle" }, data);
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledWith("admin_reverse_user_penalty", {
      penalty_action_id: "96000000-0000-4000-8000-000000000041",
      reason: "Appeal upheld with a warning",
      idempotency_key: KEY,
    });
  });
});
