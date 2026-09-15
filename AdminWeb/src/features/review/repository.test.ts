import { describe, expect, it, vi } from "vitest";

import { getReviewItem, listReviewQueue } from "./repository";

const rpc = vi.fn();

function row(overrides: Record<string, unknown> = {}) {
  return {
    kind: "content_report",
    id: "96000000-0000-4000-8000-000000000001",
    status: "open",
    severity: "severe",
    route_id: "30000000-0000-4000-8000-000000000001",
    route_label: "Blue",
    gym_name: "Urban Climb West End",
    target_type: "route",
    target_id: "30000000-0000-4000-8000-000000000001",
    title: "harassment",
    summary: "Severe report fixture",
    created_at: "2026-09-10T00:00:00.000Z",
    updated_at: "2026-09-10T00:00:00.000Z",
    ...overrides,
  };
}

describe("listReviewQueue", () => {
  it("rejects invalid input without calling the database", async () => {
    rpc.mockReset();
    const result = await listReviewQueue({ status: "bogus" }, { rpc });
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.code).toBe("invalid_input");
    expect(rpc).not.toHaveBeenCalled();
  });

  it("maps an empty page to no cursor", async () => {
    rpc.mockReset().mockResolvedValue({ data: [], error: null });
    const result = await listReviewQueue({}, { rpc });
    expect(result).toEqual({ ok: true, value: { items: [], nextCursor: null } });
    expect(rpc).toHaveBeenCalledWith("admin_review_queue", {
      status_filter: "pending",
      target_filter: "all",
      search_text: null,
      page_after: null,
      page_size: 20,
    });
  });

  it("trims the lookahead row into a continuation cursor", async () => {
    rpc.mockReset().mockResolvedValue({
      data: [
        row({ id: "96000000-0000-4000-8000-000000000001" }),
        row({
          id: "96000000-0000-4000-8000-000000000002",
          created_at: "2026-09-09T00:00:00.000Z",
        }),
        row({
          id: "96000000-0000-4000-8000-000000000003",
          created_at: "2026-09-08T00:00:00.000Z",
        }),
      ],
      error: null,
    });
    const result = await listReviewQueue({ pageSize: 2 }, { rpc });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.items.map((item) => item.id)).toEqual([
        "96000000-0000-4000-8000-000000000001",
        "96000000-0000-4000-8000-000000000002",
      ]);
      expect(result.value.nextCursor).toBe(
        "2026-09-09T00:00:00.000Z|96000000-0000-4000-8000-000000000002",
      );
      expect(result.value.items[0]?.routeLabel).toBe("Blue");
    }
  });

  it("treats rows missing target identifiers as an upstream contract failure", async () => {
    rpc.mockReset().mockResolvedValue({
      // A row without an id or target cannot be selected or inspected safely.
      data: [{ ...row(), id: undefined, target_id: null }],
      error: null,
    });
    const result = await listReviewQueue({}, { rpc });
    expect(result.ok).toBe(false);
    if (!result.ok) {
      expect(result.error.code).toBe("upstream");
      expect(result.error.traceId).toMatch(/^[0-9a-f-]{36}$/);
    }
  });

  it("converts database errors into operational errors", async () => {
    rpc.mockReset()
      .mockResolvedValueOnce({ data: null, error: { message: "boom" } })
      .mockRejectedValueOnce(new Error("network"));
    expect((await listReviewQueue({}, { rpc })).ok).toBe(false);
    const second = await listReviewQueue({}, { rpc });
    expect(second.ok).toBe(false);
    if (!second.ok) expect(second.error.code).toBe("upstream");
  });
});

describe("getReviewItem", () => {
  const detail = {
    ...row(),
    details: { category: "harassment", is_severe: true },
    reporter_id: "90000000-0000-4000-8000-000000000001",
    reviewed_by: null,
    reviewed_at: null,
    prior_actions: [
      {
        id: "96000000-0000-4000-8000-000000000041",
        action_type: "hide",
        reason: "Hide fixture",
        created_at: "2026-09-10T01:00:00.000Z",
      },
    ],
  };

  it("maps detail rows with prior actions", async () => {
    rpc.mockReset().mockResolvedValue({ data: [detail], error: null });
    const result = await getReviewItem(
      { kind: "content_report", id: detail.id },
      { rpc },
    );
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.reporterId).toBe(
        "90000000-0000-4000-8000-000000000001",
      );
      expect(result.value.priorActions).toHaveLength(1);
    }
  });

  it("returns not_found for missing or denied items", async () => {
    rpc.mockReset().mockResolvedValue({ data: [], error: null });
    const result = await getReviewItem(
      { kind: "route_correction", id: "96000000-0000-4000-8000-000000000099" },
      { rpc },
    );
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.code).toBe("not_found");
  });

  it("rejects unknown kinds before any database call", async () => {
    rpc.mockReset();
    const result = await getReviewItem({ kind: "logbook_entry", id: detail.id }, { rpc });
    expect(result.ok).toBe(false);
    expect(rpc).not.toHaveBeenCalled();
  });
});
