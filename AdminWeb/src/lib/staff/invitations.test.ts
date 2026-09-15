import { createHash } from "node:crypto";

import { beforeEach, describe, expect, it, vi } from "vitest";

import { inviteStaff, type InviteStaffDependencies } from "./invitations";

const callerRpc = vi.fn();
const inviteUserByEmail = vi.fn();
const resetPasswordForEmail = vi.fn();
const requireStaff = vi.fn();
const randomBytes = vi.fn();
const getAdminOrigin = vi.fn();

function dependencies(): InviteStaffDependencies {
  return {
    createAdminClient: () => ({
      auth: { admin: { inviteUserByEmail }, resetPasswordForEmail },
    }),
    createCallerClient: async () => ({ rpc: callerRpc }),
    getAdminOrigin,
    randomBytes,
    requireStaff,
  };
}

const input = {
  email: "  New.Moderator@BlocLens.invalid ",
  role: "moderator" as const,
  reason: "Cover the weekday moderation queue",
};

describe("inviteStaff", () => {
  beforeEach(() => {
    callerRpc.mockReset();
    inviteUserByEmail.mockReset();
    resetPasswordForEmail.mockReset().mockResolvedValue({ data: {}, error: null });
    requireStaff.mockReset();
    randomBytes.mockReset();
    getAdminOrigin.mockReset();

    requireStaff.mockResolvedValue({
      userId: "90000000-0000-4000-8000-000000000007",
      role: "admin",
      canManageAdministrators: true,
    });
    randomBytes.mockReturnValue(Buffer.alloc(32, 0xab));
    getAdminOrigin.mockReturnValue("https://operations.bloclens.example");
    callerRpc.mockResolvedValue({
      data: [
        {
          invitation_id: "95000000-0000-4000-8000-000000000010",
          invitation_created: true,
          result_status: "created",
        },
      ],
      error: null,
    });
    inviteUserByEmail.mockResolvedValue({ data: { user: { id: "invited-user" } }, error: null });
  });

  it("stores only the SHA-256 digest while putting the raw 32-byte token in the outgoing link", async () => {
    const rawToken = Buffer.alloc(32, 0xab).toString("base64url");
    const digest = createHash("sha256").update(rawToken).digest("hex");

    await expect(inviteStaff(input, dependencies())).resolves.toEqual({ status: "accepted" });

    expect(randomBytes).toHaveBeenCalledOnce();
    expect(randomBytes).toHaveBeenCalledWith(32);
    expect(callerRpc).toHaveBeenCalledWith("create_staff_invitation", {
      email: "new.moderator@bloclens.invalid",
      role: "moderator",
      token_digest: `\\x${digest}`,
      expires_at: expect.any(String),
      reason: "Cover the weekday moderation queue",
    });
    expect(JSON.stringify(callerRpc.mock.calls)).not.toContain(rawToken);
    expect(inviteUserByEmail).toHaveBeenCalledWith("new.moderator@bloclens.invalid", {
      redirectTo:
        `https://operations.bloclens.example/accept-invite?token=${rawToken}`,
    });
  });

  it("does not send a new raw token when the normalized email already has a pending invitation", async () => {
    callerRpc.mockResolvedValue({
      data: [
        {
          invitation_id: "95000000-0000-4000-8000-000000000011",
          invitation_created: false,
          result_status: "already_pending",
        },
      ],
      error: null,
    });

    await expect(inviteStaff(input, dependencies())).resolves.toEqual({ status: "accepted" });

    expect(inviteUserByEmail).not.toHaveBeenCalled();
  });

  it("returns the same safe response when the email provider reports an existing account", async () => {
    inviteUserByEmail.mockResolvedValue({
      data: { user: null },
      error: { code: "email_exists" },
    });

    const result = await inviteStaff(input, dependencies());

    expect(result).toEqual({ status: "accepted" });
    expect(result).not.toHaveProperty("error");
    expect(result).not.toHaveProperty("email");
    expect(resetPasswordForEmail).toHaveBeenCalledWith("new.moderator@bloclens.invalid", {
      redirectTo: expect.stringContaining("/accept-invite?token="),
    });
  });

  it("fails closed when SQL revalidation rejects the invitation", async () => {
    callerRpc.mockResolvedValue({ data: [{ invitation_created: false, result_status: "forbidden" }], error: null });
    await expect(inviteStaff(input, dependencies())).rejects.toThrow("Staff invitation is not permitted");
    expect(inviteUserByEmail).not.toHaveBeenCalled();
  });

  it("does not leak provider errors or send recovery for an unrelated delivery failure", async () => {
    inviteUserByEmail.mockResolvedValue({ data: null, error: { code: "unexpected_failure" } });
    await expect(inviteStaff(input, dependencies())).resolves.toEqual({ status: "accepted" });
    expect(resetPasswordForEmail).not.toHaveBeenCalled();
  });

  it("rejects Moderators before creating an invitation", async () => {
    requireStaff.mockResolvedValue({ userId: "moderator", role: "moderator", canManageAdministrators: false });
    await expect(inviteStaff(input, dependencies())).rejects.toThrow("Staff invitation is not permitted");
    expect(callerRpc).not.toHaveBeenCalled();
  });

  it("refuses an Administrator invitation before generating or sending a token when capability is absent", async () => {
    requireStaff.mockResolvedValue({
      userId: "90000000-0000-4000-8000-000000000002",
      role: "admin",
      canManageAdministrators: false,
    });

    await expect(
      inviteStaff({ ...input, role: "admin" }, dependencies()),
    ).rejects.toThrow("Staff invitation is not permitted");
    expect(randomBytes).not.toHaveBeenCalled();
    expect(callerRpc).not.toHaveBeenCalled();
    expect(inviteUserByEmail).not.toHaveBeenCalled();
  });
});
