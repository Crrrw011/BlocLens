import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { mergeRoutes } from "./merge-action";
import { MergePreview } from "./merge-preview";
import type { MergeImpact } from "./types";

const { rpc, revalidatePath, redirect, refresh } = vi.hoisted(() => ({
  rpc: vi.fn(),
  revalidatePath: vi.fn(),
  redirect: vi.fn((path: string) => {
    throw new Error(`redirect:${path}`);
  }),
  refresh: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => ({ rpc }),
}));
vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({
  redirect,
  useRouter: () => ({ refresh }),
}));

const SOURCE = "97000000-0000-4000-8000-000000000021";
const CANONICAL = "97000000-0000-4000-8000-000000000022";
const KEY = "97000000-0000-4000-8000-000000000093";
const VERSIONS = JSON.stringify({
  source: "2026-09-15T00:00:00.000Z",
  canonical: "2026-09-15T00:00:00.000Z",
});

function impact(overrides: Partial<MergeImpact> = {}): MergeImpact {
  return {
    source: { id: SOURCE, colour: "Teal", gymGrade: 3, updatedAt: "2026-09-15T00:00:00.000Z" },
    canonical: { id: CANONICAL, colour: "Cyan", gymGrade: 4, updatedAt: "2026-09-15T00:00:00.000Z" },
    counts: { logbook_entries: 2, route_photos: 2 },
    conflicts: [
      { key: `logbook_entries:${SOURCE}`, table: "logbook_entries", sourceId: SOURCE },
    ],
    ...overrides,
  };
}

function form(
  overrides: Partial<{
    sourceId: string;
    canonicalId: string;
    resolutions: string;
    reason: string;
    expectedVersions: string;
    idempotencyKey: string;
  }> = {},
) {
  const data = new FormData();
  data.set("sourceId", SOURCE);
  data.set("canonicalId", CANONICAL);
  data.set("resolutions", JSON.stringify({ [`logbook_entries:${SOURCE}`]: "skip" }));
  data.set("reason", "Duplicate confirmed on the wall");
  data.set("expectedVersions", VERSIONS);
  data.set("idempotencyKey", KEY);
  for (const [key, value] of Object.entries(overrides)) data.set(key, value);
  return data;
}

describe("MergePreview", () => {
  it("disables submit until every conflict is acknowledged", () => {
    render(
      <MergePreview impact={impact()} sourceId={SOURCE} canonicalId={CANONICAL} canExecute />,
    );
    const submit = screen.getByRole("button", { name: "Merge routes" });
    expect(submit).toBeDisabled();
    fireEvent.click(screen.getByRole("checkbox"));
    expect(submit).toBeEnabled();
  });

  it("shows counts textually without private content", () => {
    render(
      <MergePreview impact={impact()} sourceId={SOURCE} canonicalId={CANONICAL} canExecute />,
    );
    expect(screen.getByText("logbook_entries: 2")).toBeInTheDocument();
    expect(screen.queryByText(/SECRET/)).not.toBeInTheDocument();
  });

  it("withholds execution from Moderators", () => {
    render(
      <MergePreview
        impact={impact({ conflicts: [] })}
        sourceId={SOURCE}
        canonicalId={CANONICAL}
        canExecute={false}
      />,
    );
    expect(screen.queryByRole("button", { name: "Merge routes" })).not.toBeInTheDocument();
    expect(screen.getByText(/requires an Administrator/)).toBeInTheDocument();
  });
});

describe("mergeRoutes", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("executes an acknowledged merge and lands on the canonical route", async () => {
    await expect(mergeRoutes({ status: "idle" }, form())).rejects.toThrow(
      `redirect:/climbing-data/route/${CANONICAL}`,
    );
    expect(rpc).toHaveBeenCalledWith("admin_merge_routes", {
      source_id: SOURCE,
      canonical_id: CANONICAL,
      resolutions: { [`logbook_entries:${SOURCE}`]: "skip" },
      reason: "Duplicate confirmed on the wall",
      expected_versions: JSON.parse(VERSIONS),
      idempotency_key: KEY,
    });
  });

  it("requires canonical, resolutions, reason, and versions before any database call", async () => {
    for (const bad of [
      { canonicalId: "not-a-uuid" },
      { resolutions: '{"a": "delete"}' },
      { resolutions: "not-json" },
      { reason: "" },
      { expectedVersions: "{}" },
    ]) {
      const result = await mergeRoutes({ status: "idle" }, form(bad));
      expect(result.status).toBe("error");
    }
    expect(rpc).not.toHaveBeenCalled();
  });

  it("maps stale versions and unresolved conflicts distinctly", async () => {
    rpc.mockResolvedValue({ data: [{ ok: false, error_code: "conflict" }], error: null });
    const conflicted = await mergeRoutes({ status: "idle" }, form());
    expect(conflicted.status).toBe("error");
    if (conflicted.status === "error") expect("conflict" in conflicted).toBe(true);

    rpc.mockResolvedValue({
      data: [{ ok: false, error_code: "unresolved_conflicts" }],
      error: null,
    });
    const unresolved = await mergeRoutes({ status: "idle" }, form());
    expect(unresolved.status).toBe("error");
    if (unresolved.status === "error") expect("conflict" in unresolved).toBe(false);
  });
});
