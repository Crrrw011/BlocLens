import { beforeEach, expect, it, vi } from "vitest";
import { POST } from "./route";
const { inviteStaff } = vi.hoisted(() => ({ inviteStaff: vi.fn() }));
vi.mock("@/lib/staff/invitations", () => ({ inviteStaff }));
vi.mock("@/lib/auth/admin-origin", () => ({ getAdminOrigin: () => "https://operations.bloclens.example" }));
beforeEach(() => { inviteStaff.mockReset().mockResolvedValue({ status: "accepted" }); });
function request(origin = "https://operations.bloclens.example", body = JSON.stringify({ email: "staff@example.com", role: "moderator", reason: "Queue coverage" })) {
  return new Request("https://operations.bloclens.example/api/staff/invitations", { method: "POST", headers: { origin, "content-type": "application/json" }, body });
}
it("rejects cross-origin submissions before privileged work", async () => {
  expect((await POST(request("https://attacker.example"))).status).toBe(403);
  expect(inviteStaff).not.toHaveBeenCalled();
});
it("returns a generic uncached acknowledgment", async () => {
  const response = await POST(request());
  expect(response.status).toBe(202);
  expect(await response.json()).toEqual({ status: "accepted" });
  expect(response.headers.get("cache-control")).toBe("no-store");
});
it("rejects malformed inputs without invoking the invitation helper", async () => {
  expect((await POST(request(undefined, "{}"))).status).toBe(400);
  expect(inviteStaff).not.toHaveBeenCalled();
});
it("does not expose permission or provider errors", async () => {
  inviteStaff.mockRejectedValue(new Error("private error"));
  const response = await POST(request());
  expect(response.status).toBe(403);
  expect(await response.text()).not.toContain("private error");
});
