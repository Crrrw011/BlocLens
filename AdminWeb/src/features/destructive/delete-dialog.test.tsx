import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { permanentDelete } from "./delete-action";
import { DeleteDialog } from "./delete-dialog";
import type { DeletionImpact } from "../climbing-data/types";

const { rpc, remove, redirect, requireStaff } = vi.hoisted(() => ({
  rpc: vi.fn(),
  remove: vi.fn(),
  redirect: vi.fn((path: string) => {
    throw new Error(`redirect:${path}`);
  }),
  requireStaff: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => ({ rpc }),
}));
vi.mock("@/lib/supabase/admin", () => ({
  createAdminClient: () => ({ storage: { from: () => ({ remove }) } }),
}));
vi.mock("@/lib/auth/access", () => ({ requireStaff }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("next/navigation", () => ({ redirect }));

const ID = "96000000-0000-4000-8000-000000000006";
const KEY = "96000000-0000-4000-8000-000000000014";
const VERSION = "2026-09-15T00:00:00.000Z";

function impact(overrides: Partial<DeletionImpact> = {}): DeletionImpact {
  return {
    eligible: true,
    blockers: [],
    dependentCounts: { helpful_votes: 2 },
    storagePaths: ["deletion/photo-1.jpg"],
    alternative: null,
    ...overrides,
  };
}

function renderDialog(propsImpact: DeletionImpact = impact()) {
  return render(
    <DeleteDialog
      targetType="route_photo"
      targetId={ID}
      title="deletion/photo-1.jpg"
      impact={propsImpact}
      expectedUpdatedAt={VERSION}
    />,
  );
}

describe("DeleteDialog", () => {
  it("shows exact dependencies on warning one", () => {
    renderDialog();
    fireEvent.click(screen.getByRole("button", { name: "Delete…" }));
    expect(screen.getByText("helpful_votes: 2")).toBeInTheDocument();
    expect(screen.getByText("file: deletion/photo-1.jpg")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Continue" })).toBeEnabled();
  });

  it("withholds continue when blocked", () => {
    renderDialog(impact({ eligible: false, blockers: ["has_comments"], alternative: null }));
    fireEvent.click(screen.getByRole("button", { name: "Delete…" }));
    expect(screen.queryByRole("button", { name: "Continue" })).not.toBeInTheDocument();
    expect(screen.getByText(/cannot be deleted/)).toBeInTheDocument();
  });

  it("requires an exact DELETE phrase and resets it on back navigation", () => {
    renderDialog();
    fireEvent.click(screen.getByRole("button", { name: "Delete…" }));
    fireEvent.click(screen.getByRole("button", { name: "Continue" }));

    const confirm = screen.getByRole("button", { name: "Delete permanently" });
    expect(confirm).toBeDisabled();
    fireEvent.change(screen.getByLabelText("Type DELETE in capitals"), {
      target: { value: "delete" },
    });
    expect(confirm).toBeDisabled();
    fireEvent.change(screen.getByLabelText("Type DELETE in capitals"), {
      target: { value: "DELETE" },
    });
    expect(confirm).toBeEnabled();

    fireEvent.click(screen.getByRole("button", { name: "Back" }));
    expect(screen.getByRole("button", { name: "Continue" })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Continue" }));
    expect(screen.getByLabelText("Type DELETE in capitals")).toHaveValue("");
    expect(screen.getByRole("button", { name: "Delete permanently" })).toBeDisabled();
  });
});

function form(
  overrides: Partial<{
    targetType: string;
    targetId: string;
    reason: string;
    expectedUpdatedAt: string;
    idempotencyKey: string;
    confirmation: string;
  }> = {},
) {
  const data = new FormData();
  data.set("targetType", "route_photo");
  data.set("targetId", ID);
  data.set("reason", "Blurry duplicate with no references");
  data.set("expectedUpdatedAt", VERSION);
  data.set("idempotencyKey", KEY);
  data.set("confirmation", "DELETE");
  for (const [key, value] of Object.entries(overrides)) data.set(key, value);
  return data;
}

describe("permanentDelete", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    requireStaff.mockResolvedValue({ userId: "admin", role: "admin", canManageAdministrators: true });
    rpc
      .mockResolvedValueOnce({
        data: [{ eligible: true, blockers: [], storage_paths: [], dependent_counts: {} }],
        error: null,
      })
      .mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("deletes eligible records and returns to the list", async () => {
    await expect(permanentDelete({ status: "idle" }, form())).rejects.toThrow(
      "redirect:/climbing-data/route_photo",
    );
    expect(rpc).toHaveBeenCalledWith("admin_permanently_delete", {
      target_type: "route_photo",
      target_id: ID,
      reason: "Blurry duplicate with no references",
      expected_updated_at: VERSION,
      idempotency_key: KEY,
    });
  });

  it("refuses blocked targets before deleting", async () => {
    rpc.mockReset().mockResolvedValue({
      data: [{ eligible: false, blockers: ["has_comments"], storage_paths: [], dependent_counts: {} }],
      error: null,
    });
    const result = await permanentDelete({ status: "idle" }, form());
    expect(result.status).toBe("error");
    expect(rpc).toHaveBeenCalledOnce();
  });

  it("never claims database success when file cleanup fails", async () => {
    process.env.ROUTE_PHOTOS_BUCKET = "test-bucket";
    try {
      rpc.mockReset().mockResolvedValue({
        data: [
          {
            eligible: true,
            blockers: [],
            storage_paths: ["deletion/photo-1.jpg"],
            dependent_counts: {},
          },
        ],
        error: null,
      });
      remove.mockResolvedValue({ error: { message: "storage down" } });
      const result = await permanentDelete({ status: "idle" }, form());
      expect(result.status).toBe("error");
      expect(rpc).toHaveBeenCalledOnce();
      expect(remove).toHaveBeenCalledWith(["deletion/photo-1.jpg"]);
    } finally {
      delete process.env.ROUTE_PHOTOS_BUCKET;
    }
  });

  it("requires an Administrator, a reason, and an exact DELETE", async () => {
    requireStaff.mockResolvedValue({ userId: "mod", role: "moderator", canManageAdministrators: false });
    const denied = await permanentDelete({ status: "idle" }, form());
    expect(denied.status).toBe("error");
    expect(rpc).not.toHaveBeenCalled();

    requireStaff.mockResolvedValue({ userId: "admin", role: "admin", canManageAdministrators: true });
    for (const bad of [{ reason: "" }, { confirmation: "delete" }, { targetId: "nope" }]) {
      const result = await permanentDelete({ status: "idle" }, form(bad));
      expect(result.status).toBe("error");
    }
  });
});
