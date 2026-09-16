import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { decideClaim } from "./claim-actions";
import { ClaimsTable } from "./claims-table";
import type { ClaimRow } from "./claim-inspector";

const { rpc, revalidatePath, push } = vi.hoisted(() => ({
  rpc: vi.fn(),
  revalidatePath: vi.fn(),
  push: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => ({ rpc }),
}));
vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push, refresh: vi.fn() }),
  usePathname: () => "/people/claims",
  useSearchParams: () => new URLSearchParams(),
}));

function claim(overrides: Partial<ClaimRow> = {}): ClaimRow {
  return {
    id: "99000000-0000-4000-8000-000000000001",
    gymId: "10000000-0000-4000-8000-000000000001",
    gymName: "Urban Climb West End",
    applicantId: "90000000-0000-4000-8000-000000000005",
    applicantName: "Fixture Gym Official",
    domainEmail: "manager@example.invalid",
    verificationMethod: "manual_review",
    status: "submitted",
    reviewNote: null,
    updatedAt: "2026-09-15T00:00:00.000Z",
    createdAt: "2026-09-15T00:00:00.000Z",
    ...overrides,
  };
}

describe("ClaimsTable", () => {
  it("renders gym context and opens the inspector on selection", () => {
    push.mockReset();
    render(<ClaimsTable claims={[claim()]} selected={claim()} />);
    expect(screen.getByRole("columnheader", { name: "Gym" })).toBeInTheDocument();
    expect(screen.getByRole("dialog", { name: "Gym claims" })).toBeVisible();
    expect(
      screen.getByText("Fixture Gym Official · manager@example.invalid"),
    ).toBeInTheDocument();
  });

  it("selects a row without losing list state", () => {
    push.mockReset();
    render(<ClaimsTable claims={[claim()]} selected={null} />);
    fireEvent.click(screen.getByRole("cell", { name: "Urban Climb West End" }));
    expect(push).toHaveBeenCalledOnce();
    expect(push.mock.calls[0]?.[0] as string).toContain(
      `selected=${claim().id}`,
    );
  });

  it("shows an empty state instead of an empty table", () => {
    render(<ClaimsTable claims={[]} selected={null} />);
    expect(screen.getByText("No gym claims")).toBeInTheDocument();
  });
});

function form(
  overrides: Partial<{ claimId: string; decision: string; reviewNote: string }> = {},
) {
  const data = new FormData();
  data.set("claimId", claim().id);
  data.set("decision", "approved");
  data.set("reviewNote", "Domain matches the gym website");
  data.set("expectedUpdatedAt", "2026-09-15T00:00:00.000Z");
  data.set("idempotencyKey", "99000000-0000-4000-8000-000000000011");
  for (const [key, value] of Object.entries(overrides)) data.set(key, value);
  return data;
}

describe("decideClaim", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("approves with a note and revalidates claims views", async () => {
    const result = await decideClaim({ status: "idle" }, form());
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledWith("admin_decide_gym_claim", {
      claim_id: claim().id,
      decision: "approved",
      review_note: "Domain matches the gym website",
      expected_updated_at: "2026-09-15T00:00:00.000Z",
      idempotency_key: "99000000-0000-4000-8000-000000000011",
    });
    expect(revalidatePath).toHaveBeenCalledWith("/people/claims");
  });

  it("requires a decision and note before any database call", async () => {
    for (const bad of [{ decision: "maybe" }, { reviewNote: "" }, { claimId: "nope" }]) {
      const result = await decideClaim({ status: "idle" }, form(bad));
      expect(result.status).toBe("error");
    }
    expect(rpc).not.toHaveBeenCalled();
  });

  it("maps stale versions to a conflict state", async () => {
    rpc.mockResolvedValue({ data: [{ ok: false, error_code: "conflict" }], error: null });
    const result = await decideClaim({ status: "idle" }, form());
    expect(result.status).toBe("error");
    if (result.status === "error") expect("conflict" in result).toBe(true);
  });
});
