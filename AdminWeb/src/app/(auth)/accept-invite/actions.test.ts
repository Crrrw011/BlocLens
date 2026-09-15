import { beforeEach, describe, expect, it, vi } from "vitest";
import { acceptInvitation } from "./actions";

const { getUser, updateUser, rpc, redirect } = vi.hoisted(() => ({
  getUser: vi.fn(), updateUser: vi.fn(), rpc: vi.fn(),
  redirect: vi.fn((path: string) => { throw new Error(`redirect:${path}`); }),
}));
vi.mock("@/lib/supabase/server", () => ({ createServerClient: async () => ({ auth: { getUser, updateUser }, rpc }) }));
vi.mock("next/navigation", () => ({ redirect }));

function form(password = "InvitationPassword1!", confirmation = password) {
  const data = new FormData();
  data.set("password", password);
  data.set("passwordConfirmation", confirmation);
  data.set("tokenDigest", "ab".repeat(32));
  return data;
}
describe("acceptInvitation", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getUser.mockResolvedValue({ data: { user: { id: "recipient", email_confirmed_at: "2026-09-12" } }, error: null });
    updateUser.mockResolvedValue({ data: {}, error: null });
    rpc.mockResolvedValue({ data: [{ invitation_accepted: true }], error: null });
  });
  it("sets the authenticated recipient password and activates the invited role before redirecting", async () => {
    await expect(acceptInvitation(form())).rejects.toThrow("redirect:/overview");
    expect(updateUser).toHaveBeenCalledWith({ password: "InvitationPassword1!" });
    expect(rpc).toHaveBeenCalledWith("accept_staff_invitation", { token_digest: `\\x${"ab".repeat(32)}` });
    expect(updateUser.mock.invocationCallOrder[0]).toBeLessThan(rpc.mock.invocationCallOrder[0]);
  });
  it("requires a valid authenticated recipient before changing credentials", async () => {
    getUser.mockResolvedValue({ data: { user: null }, error: null });
    expect((await acceptInvitation(form())).status).toBe("error");
    expect(updateUser).not.toHaveBeenCalled();
    expect(rpc).not.toHaveBeenCalled();
  });
  it("does not consume the invitation if password update fails", async () => {
    updateUser.mockResolvedValue({ data: {}, error: { code: "weak_password" } });
    expect((await acceptInvitation(form())).status).toBe("error");
    expect(rpc).not.toHaveBeenCalled();
  });
  it.each(["revoked", "expired", "already_accepted", "inviter_not_authorized"])("does not redirect when SQL rejects %s", async (result_status) => {
    rpc.mockResolvedValue({ data: [{ invitation_accepted: false, result_status }], error: null });
    expect((await acceptInvitation(form())).status).toBe("error");
    expect(redirect).not.toHaveBeenCalled();
  });
  it("rejects short or mismatched passwords before Auth operations", async () => {
    expect((await acceptInvitation(form("short"))).status).toBe("error");
    expect((await acceptInvitation(form("LongPassword1!", "different"))).status).toBe("error");
    expect(getUser).not.toHaveBeenCalled();
  });
});
