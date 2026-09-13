import { beforeEach, describe, expect, it, vi } from "vitest";

const resetPasswordForEmail = vi.fn();
const updateUser = vi.fn();
const getAdminOrigin = vi.fn();

vi.mock("@/lib/supabase/server", () => ({
  createServerClient: vi.fn(async () => ({
    auth: { resetPasswordForEmail, updateUser },
  })),
}));

vi.mock("@/lib/auth/admin-origin", () => ({
  getAdminOrigin,
}));

vi.mock("next/navigation", () => ({
  redirect: vi.fn((location: string): never => {
    throw new Error(`redirect:${location}`);
  }),
}));

describe("requestPasswordReset", () => {
  beforeEach(() => {
    vi.resetModules();
    resetPasswordForEmail.mockReset();
    updateUser.mockReset();
    getAdminOrigin.mockReset();
  });

  it("uses the same successful response when the email is malformed", async () => {
    const { requestPasswordReset } = await import("./password-actions");
    const formData = new FormData();
    formData.set("email", "not-an-email");

    await expect(requestPasswordReset(formData)).resolves.toEqual({ status: "success" });
    expect(resetPasswordForEmail).not.toHaveBeenCalled();
  });

  it("does not reveal whether a valid email has an account", async () => {
    resetPasswordForEmail.mockResolvedValue({ error: new Error("unknown user") });
    getAdminOrigin.mockReturnValue("http://127.0.0.1:3000");
    const { requestPasswordReset } = await import("./password-actions");
    const formData = new FormData();
    formData.set("email", "staff@bloclens.invalid");

    await expect(requestPasswordReset(formData)).resolves.toEqual({ status: "success" });
    expect(resetPasswordForEmail).toHaveBeenCalledWith("staff@bloclens.invalid", {
      redirectTo: "http://127.0.0.1:3000/update-password",
    });
    expect(getAdminOrigin).toHaveBeenCalledOnce();
  });
});

describe("updatePassword", () => {
  beforeEach(() => {
    vi.resetModules();
    resetPasswordForEmail.mockReset();
    updateUser.mockReset();
    getAdminOrigin.mockReset();
  });

  it("rejects a password confirmation mismatch without updating the user", async () => {
    const { updatePassword } = await import("./password-actions");
    const formData = new FormData();
    formData.set("password", "long-enough-password");
    formData.set("passwordConfirmation", "different-password");

    await expect(updatePassword(formData)).resolves.toEqual({
      status: "error",
      message: "Passwords must match.",
    });
    expect(updateUser).not.toHaveBeenCalled();
  });

  it("does not redirect when Supabase rejects the new password", async () => {
    updateUser.mockResolvedValue({ error: new Error("expired recovery") });
    const { updatePassword } = await import("./password-actions");
    const formData = new FormData();
    formData.set("password", "long-enough-password");
    formData.set("passwordConfirmation", "long-enough-password");

    await expect(updatePassword(formData)).resolves.toEqual({
      status: "error",
      message: "Unable to update your password. Request a new reset link.",
    });
  });

  it("updates the password and continues to the protected portal", async () => {
    updateUser.mockResolvedValue({ error: null });
    const { updatePassword } = await import("./password-actions");
    const formData = new FormData();
    formData.set("password", "long-enough-password");
    formData.set("passwordConfirmation", "long-enough-password");

    await expect(updatePassword(formData)).rejects.toThrow("redirect:/overview");
    expect(updateUser).toHaveBeenCalledWith({ password: "long-enough-password" });
  });
});
