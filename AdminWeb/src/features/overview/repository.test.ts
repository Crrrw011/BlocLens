import { describe, expect, it, vi } from "vitest";

import { getOverviewMetrics } from "./repository";

const rpc = vi.fn();

function metricsRow(overrides: Record<string, unknown> = {}) {
  return {
    pending_reports: 3,
    severe_reports: 1,
    pending_corrections: 2,
    duplicate_routes: 1,
    pending_claims: 0,
    hidden_content: 0,
    median_handling_seconds: 4210.5,
    trend: [{ day: "2026-09-14", opened: 2, resolved: 1 }],
    distribution: [{ kind: "content_report", status: "open", count: 3 }],
    recent_actions: [
      {
        id: "96000000-0000-4000-8000-000000000041",
        action_type: "hide",
        target_type: "route",
        target_id: "30000000-0000-4000-8000-000000000001",
        reason: "Hide fixture",
        created_at: "2026-09-14T00:00:00.000Z",
      },
    ],
    ...overrides,
  };
}

describe("getOverviewMetrics", () => {
  it("rejects unknown ranges without calling the database", async () => {
    rpc.mockReset();
    const result = await getOverviewMetrics("13d", { rpc });
    expect(result.ok).toBe(false);
    expect(rpc).not.toHaveBeenCalled();
  });

  it("maps counts, trend, and recent actions", async () => {
    rpc.mockReset().mockResolvedValue({ data: [metricsRow()], error: null });
    const result = await getOverviewMetrics("7d", { rpc });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.pendingReports).toBe(3);
      expect(result.value.medianHandlingSeconds).toBe(4210.5);
      expect(result.value.trend).toHaveLength(1);
      expect(result.value.recentActions[0]?.actionType).toBe("hide");
    }
    const parameters = rpc.mock.calls[0]?.[1] as Record<string, string>;
    expect(parameters.range_start < parameters.range_end).toBe(true);
  });

  it("keeps a null median when nothing resolved in range", async () => {
    rpc.mockReset().mockResolvedValue({
      data: [metricsRow({ median_handling_seconds: null, trend: [] })],
      error: null,
    });
    const result = await getOverviewMetrics("90d", { rpc });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.medianHandlingSeconds).toBeNull();
      expect(result.value.trend).toEqual([]);
    }
  });

  it("returns not_found for denied callers and upstream for malformed rows", async () => {
    rpc.mockReset().mockResolvedValue({ data: [], error: null });
    const denied = await getOverviewMetrics("30d", { rpc });
    expect(denied.ok).toBe(false);
    if (!denied.ok) expect(denied.error.code).toBe("not_found");

    rpc.mockReset().mockResolvedValue({
      data: [{ ...metricsRow(), pending_reports: "lots" }],
      error: null,
    });
    const malformed = await getOverviewMetrics("30d", { rpc });
    expect(malformed.ok).toBe(false);
    if (!malformed.ok) expect(malformed.error.code).toBe("upstream");
  });
});
