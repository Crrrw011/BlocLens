import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { revokeInvitation, setStaffActive } from "./staff-actions";
import { StaffTables } from "./staff-table";
import type { StaffInvitation, StaffMember } from "./repository";

const { rpc, revalidatePath } = vi.hoisted(() => ({
  rpc: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => ({ rpc }),
}));
vi.mock("next/cache", () => ({ revalidatePath }));
vi.mock("@/lib/supabase/admin", () => ({
  createAdminClient: () => {
    throw new Error("admin client is unavailable in staff tests");
  },
}));

const staff: StaffMember[] = [
  {
    user_id: "90000000-0000-4000-8000-000000000007",
    username: "Fixture Administrator",
    role: "admin",
    active: true,
    can_manage_administrators: true,
    since: "2026-08-20T00:00:00.000Z",
  },
  {
    user_id: "90000000-0000-4000-8000-000000000006",
    username: "Fixture Moderator",
    role: "moderator",
    active: true,
    can_manage_administrators: false,
    since: "2026-08-20T00:00:00.000Z",
  },
];

const invitations: StaffInvitation[] = [
  {
    id: "95000000-0000-4000-8000-000000000001",
    email: "pending@bloclens.invalid",
    role: "moderator",
    status: "pending",
    expires_at: "2026-09-16T00:00:00.000Z",
    invited_by: "90000000-0000-4000-8000-000000000007",
    created_at: "2026-09-15T00:00:00.000Z",
  },
  {
    id: "95000000-0000-4000-8000-000000000002",
    email: "gone@bloclens.invalid",
    role: "moderator",
    status: "revoked",
    expires_at: "2026-09-16T00:00:00.000Z",
    invited_by: "90000000-0000-4000-8000-000000000007",
    created_at: "2026-09-14T00:00:00.000Z",
  },
];

describe("StaffTables", () => {
  it("renders roster states, invitation badges, and owner-gated controls", () => {
    render(<StaffTables staff={staff} invitations={invitations} canManageAdministrators />);
    expect(screen.getByText("Fixture Administrator")).toBeInTheDocument();
    expect(screen.getByText("Pending", { exact: true })).toBeInTheDocument();
    expect(screen.getByText("Revoked", { exact: true })).toBeInTheDocument();
    // Owner sees deactivate for both rows; revocation only for pending.
    expect(screen.getAllByRole("button", { name: "Deactivate" })).toHaveLength(2);
    expect(screen.getAllByRole("button", { name: "Revoke" })).toHaveLength(1);
  });

  it("withholds administrator deactivation without the owner capability", () => {
    render(<StaffTables staff={staff} invitations={[]} canManageAdministrators={false} />);
    // Only the moderator row offers deactivation now.
    expect(screen.getAllByRole("button", { name: "Deactivate" })).toHaveLength(1);
  });

  it("asks for a reason before revoking", () => {
    render(<StaffTables staff={staff} invitations={invitations} canManageAdministrators />);
    fireEvent.click(screen.getByRole("button", { name: "Revoke" }));
    expect(screen.getByRole("dialog", { name: "Revoke" })).toBeVisible();
    expect(screen.getByLabelText("Reason", { exact: false })).toBeInTheDocument();
  });
});

function revokeForm(overrides: Record<string, string> = {}) {
  const data = new FormData();
  data.set("invitationId", invitations[0]!.id);
  data.set("reason", "Hiring freeze");
  data.set("idempotencyKey", "98000000-0000-4000-8000-000000000021");
  for (const [key, value] of Object.entries(overrides)) data.set(key, value);
  return data;
}

describe("revokeInvitation", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("revokes with a reason and revalidates staff views", async () => {
    const result = await revokeInvitation({ status: "idle" }, revokeForm());
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledWith("admin_revoke_staff_invitation", {
      invitation_id: invitations[0]!.id,
      reason: "Hiring freeze",
      idempotency_key: "98000000-0000-4000-8000-000000000021",
    });
    expect(revalidatePath).toHaveBeenCalledWith("/staff");
    expect(revalidatePath).toHaveBeenCalledWith("/people");
  });

  it("requires a reason before any database call", async () => {
    const result = await revokeInvitation({ status: "idle" }, revokeForm({ reason: "" }));
    expect(result.status).toBe("error");
    expect(rpc).not.toHaveBeenCalled();
  });
});

describe("setStaffActive", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  function accessForm() {
    const data = new FormData();
    data.set("targetUserId", "90000000-0000-4000-8000-000000000006");
    data.set("makeActive", "false");
    data.set("reason", "Role review in progress");
    data.set("idempotencyKey", "98000000-0000-4000-8000-000000000024");
    return data;
  }

  it("deactivates and revalidates staff views", async () => {
    const result = await setStaffActive({ status: "idle" }, accessForm());
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledWith("admin_set_staff_active", {
      target_user_id: "90000000-0000-4000-8000-000000000006",
      make_active: false,
      reason: "Role review in progress",
      idempotency_key: "98000000-0000-4000-8000-000000000024",
    });
  });
});
