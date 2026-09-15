import { describe, expect, it, vi } from "vitest";

import { listUsers } from "./repository";

const rpc = vi.fn();

function row(overrides: Record<string, unknown> = {}) {
  return {
    user_id: "90000000-0000-4000-8000-000000000001",
    username: "Fixture Climber One",
    member_since: "2026-08-20T00:00:00.000Z",
    staff_role: null,
    restriction_kinds: [],
    ...overrides,
  };
}

describe("listUsers", () => {
  it("rejects invalid input without calling the database", async () => {
    rpc.mockReset();
    const result = await listUsers({ q: 42 }, rpc);
    expect(result.ok).toBe(false);
    expect(rpc).not.toHaveBeenCalled();
  });

  it("maps rows and trims the lookahead into a cursor", async () => {
    rpc.mockReset().mockResolvedValue({
      data: [
        row(),
        row({
          user_id: "90000000-0000-4000-8000-000000000002",
          username: "Fixture Climber Two",
          restriction_kinds: ["timed_suspension"],
        }),
      ],
      error: null,
    });
    const result = await listUsers({ q: "Fixture", pageSize: 1 }, rpc);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.items).toHaveLength(1);
      expect(result.value.nextCursor).toContain("90000000-0000-4000-8000-000000000001");
    }
    expect(rpc).toHaveBeenCalledWith("admin_list_users", {
      search_text: "Fixture",
      page_after: null,
      page_size: 1,
    });
  });

  it("treats malformed rows as upstream failures", async () => {
    rpc.mockReset().mockResolvedValue({
      data: [{ ...row(), user_id: "nope" }],
      error: null,
    });
    const result = await listUsers({}, rpc);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.code).toBe("upstream");
  });
});
