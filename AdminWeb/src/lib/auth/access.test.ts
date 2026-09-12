import { beforeEach, describe, expect, it, vi } from "vitest";

const getUser = vi.fn();
const rpc = vi.fn();
const signInWithPassword = vi.fn();

vi.mock("@/lib/supabase/server", () => ({
  createServerClient: vi.fn(async () => ({
    auth: { getUser, signInWithPassword },
    rpc,
  })),
}));

vi.mock("next/navigation", () => ({
  redirect: vi.fn((location: string): never => {
    throw new Error(`redirect:${location}`);
  }),
}));

function mockAuthenticatedUser(userId = "staff-user") {
  getUser.mockResolvedValue({ data: { user: { id: userId } }, error: null });
}

function mockAccess(
  data: {
    user_id: string;
    role: "admin" | "moderator";
    can_manage_administrators: boolean;
    is_active: boolean;
  } | null,
) {
  rpc.mockReturnValue({
    maybeSingle: vi.fn().mockResolvedValue({ data, error: null }),
  });
}

describe("requireStaff", () => {
  beforeEach(() => {
    vi.resetModules();
    getUser.mockReset();
    rpc.mockReset();
    signInWithPassword.mockReset();
  });

  it("redirects a visitor without a validated session to sign-in", async () => {
    getUser.mockResolvedValue({ data: { user: null }, error: null });
    const { requireStaff } = await import("./access");

    await expect(requireStaff()).rejects.toThrow("redirect:/sign-in");
    expect(rpc).not.toHaveBeenCalled();
  });

  it("denies an authenticated user whose staff role is inactive", async () => {
    mockAuthenticatedUser();
    mockAccess({
      user_id: "staff-user",
      role: "moderator",
      can_manage_administrators: false,
      is_active: false,
    });
    const { requireStaff } = await import("./access");

    await expect(requireStaff()).rejects.toThrow("redirect:/access-denied");
  });

  it("returns a Moderator without administrator-management capability", async () => {
    mockAuthenticatedUser();
    mockAccess({
      user_id: "staff-user",
      role: "moderator",
      can_manage_administrators: true,
      is_active: true,
    });
    const { requireStaff } = await import("./access");

    await expect(requireStaff()).resolves.toEqual({
      userId: "staff-user",
      role: "moderator",
      canManageAdministrators: false,
    });
  });

  it("returns an active Administrator without owner capability", async () => {
    mockAuthenticatedUser();
    mockAccess({
      user_id: "staff-user",
      role: "admin",
      can_manage_administrators: false,
      is_active: true,
    });
    const { requireStaff } = await import("./access");

    await expect(requireStaff()).resolves.toEqual({
      userId: "staff-user",
      role: "admin",
      canManageAdministrators: false,
    });
  });

  it("returns owner capability only for an active Administrator", async () => {
    mockAuthenticatedUser();
    mockAccess({
      user_id: "staff-user",
      role: "admin",
      can_manage_administrators: true,
      is_active: true,
    });
    const { requireStaff } = await import("./access");

    await expect(requireStaff()).resolves.toEqual({
      userId: "staff-user",
      role: "admin",
      canManageAdministrators: true,
    });
  });
});

describe("signIn", () => {
  beforeEach(() => {
    vi.resetModules();
    getUser.mockReset();
    rpc.mockReset();
    signInWithPassword.mockReset();
  });

  it("uses the same credential error for malformed input", async () => {
    const { signIn } = await import("@/app/(auth)/sign-in/actions");
    const formData = new FormData();
    formData.set("email", "not-an-email");
    formData.set("password", "short");

    await expect(signIn(formData)).resolves.toEqual({
      status: "error",
      message: "Unable to sign in with those credentials.",
    });
    expect(signInWithPassword).not.toHaveBeenCalled();
  });

  it("uses the same credential error for rejected credentials", async () => {
    signInWithPassword.mockResolvedValue({ error: new Error("invalid login") });
    const { signIn } = await import("@/app/(auth)/sign-in/actions");
    const formData = new FormData();
    formData.set("email", "staff@bloclens.invalid");
    formData.set("password", "valid-password");

    await expect(signIn(formData)).resolves.toEqual({
      status: "error",
      message: "Unable to sign in with those credentials.",
    });
  });
});
