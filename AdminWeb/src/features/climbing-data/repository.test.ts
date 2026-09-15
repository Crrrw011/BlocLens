import { describe, expect, it, vi } from "vitest";

import { getEntityDetail, listEntities } from "./repository";

const rpc = vi.fn();

function row(overrides: Record<string, unknown> = {}) {
  return {
    kind: "route",
    id: "99000000-0000-4000-8000-000000000003",
    status: "hidden",
    title: "Teal",
    subtitle: "Projection Gym · Projection Slab",
    moderation: "temporarily_hidden",
    dependent_counts: { photos: 1, beta_links: 1 },
    updated_at: "2026-09-15T00:00:00.000Z",
    created_at: "2026-09-14T00:00:00.000Z",
    ...overrides,
  };
}

describe("listEntities", () => {
  it("rejects unknown kinds without calling the database", async () => {
    rpc.mockReset();
    const result = await listEntities({ kind: "logbook_entry" }, rpc);
    expect(result.ok).toBe(false);
    expect(rpc).not.toHaveBeenCalled();
  });

  it("maps rows and trims the lookahead into a cursor", async () => {
    rpc.mockReset().mockResolvedValue({
      data: [
        row(),
        row({ id: "99000000-0000-4000-8000-000000000004", updated_at: "2026-09-14T12:00:00.000Z" }),
      ],
      error: null,
    });
    const result = await listEntities({ kind: "route", pageSize: 1 }, rpc);
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.items).toHaveLength(1);
      expect(result.value.items[0]?.dependentCounts).toEqual({ photos: 1, beta_links: 1 });
      expect(result.value.nextCursor).toBe(
        "2026-09-15T00:00:00.000Z|99000000-0000-4000-8000-000000000003",
      );
    }
    expect(rpc).toHaveBeenCalledWith("admin_list_entities", {
      entity_kind: "route",
      status_filter: "all",
      search_text: null,
      gym_id: null,
      page_after: null,
      page_size: 1,
    });
  });

  it("treats rows with invalid identifiers as upstream failures", async () => {
    rpc.mockReset().mockResolvedValue({
      data: [{ ...row(), id: "not-a-uuid" }],
      error: null,
    });
    const result = await listEntities({ kind: "route" }, rpc);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.code).toBe("upstream");
  });

  it("converts database errors into operational errors", async () => {
    rpc.mockReset().mockResolvedValue({ data: null, error: { message: "boom" } });
    const result = await listEntities({ kind: "gym" }, rpc);
    expect(result.ok).toBe(false);
  });
});

describe("getEntityDetail", () => {
  it("maps detail rows with moderation history", async () => {
    rpc.mockReset().mockResolvedValue({
      data: [
        {
          ...row(),
          details: { colour: "Teal", gym_grade: 3 },
          related: { photos: ["99000000-0000-4000-8000-000000000005"] },
          moderation_history: [
            {
              id: "96000000-0000-4000-8000-000000000041",
              action_type: "hide",
              reason: "Hide fixture",
              created_at: "2026-09-14T00:00:00.000Z",
            },
          ],
        },
      ],
      error: null,
    });
    const result = await getEntityDetail(
      { kind: "route", id: "99000000-0000-4000-8000-000000000003" },
      rpc,
    );
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.details).toEqual({ colour: "Teal", gym_grade: 3 });
      expect(result.value.moderationHistory).toHaveLength(1);
    }
  });

  it("returns not_found for missing or denied entities", async () => {
    rpc.mockReset().mockResolvedValue({ data: [], error: null });
    const result = await getEntityDetail(
      { kind: "gym", id: "99000000-0000-4000-8000-000000000099" },
      rpc,
    );
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error.code).toBe("not_found");
  });
});
