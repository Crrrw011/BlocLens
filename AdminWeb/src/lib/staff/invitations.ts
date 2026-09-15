import "server-only";
import { createHash, randomBytes } from "node:crypto";
import { z } from "zod";
import type { StaffAccess, StaffRole } from "@/lib/auth/access";

export type InviteStaffDependencies = {
  createAdminClient: () => {
    auth: {
      resetPasswordForEmail: (email: string, options: { redirectTo: string }) => Promise<{ data: unknown; error: unknown }>;
      admin: {
        inviteUserByEmail: (
          email: string,
          options: { redirectTo: string },
        ) => Promise<{ data: unknown; error: unknown }>;
      };
    };
  };
  createCallerClient: () => Promise<{
    rpc: (
      functionName: string,
      parameters: Record<string, unknown>,
    ) => PromiseLike<{ data: unknown; error: unknown }>;
  }>;
  getAdminOrigin: () => string;
  randomBytes: (size: number) => Uint8Array;
  requireStaff: () => Promise<StaffAccess>;
};

export type InviteStaffInput = {
  email: string;
  role: StaffRole;
  reason: string;
};

export async function inviteStaff(
  input: InviteStaffInput,
  dependencies?: InviteStaffDependencies,
): Promise<{ status: "accepted" }> {
  const deps = dependencies ?? await defaultDependencies();
  const staff = await deps.requireStaff();
  const parsed = z.object({
    email: z.string().trim().email().max(320).transform((value) => value.toLowerCase()),
    role: z.enum(["admin", "moderator"]),
    reason: z.string().trim().min(1).max(2000),
  }).parse(input);
  if (staff.role !== "admin" || (parsed.role === "admin" && !staff.canManageAdministrators)) {
    throw new Error("Staff invitation is not permitted");
  }
  const token = Buffer.from(deps.randomBytes(32)).toString("base64url");
  const tokenDigest = createHash("sha256").update(token).digest("hex");
  const redirectTo = new URL("/accept-invite", deps.getAdminOrigin());
  redirectTo.searchParams.set("token", token);
  const caller = await deps.createCallerClient();
  const { data, error } = await caller.rpc("create_staff_invitation", {
    ...parsed,
    token_digest: `\\x${tokenDigest}`,
    expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
  });
  const result = Array.isArray(data) ? data[0] : null;
  if (error || !result || result.result_status === "forbidden") {
    throw new Error("Staff invitation is not permitted");
  }
  if (result.invitation_created) {
    const admin = deps.createAdminClient();
    // Only the outbound Auth redirect carries the raw invitation token.
    // Existing climbing accounts receive a recovery link to the same flow.
    const delivery = await admin.auth.admin.inviteUserByEmail(parsed.email, { redirectTo: redirectTo.toString() });
    if (delivery.error && typeof delivery.error === "object" && "code" in delivery.error && delivery.error.code === "email_exists") {
      await admin.auth.resetPasswordForEmail(parsed.email, { redirectTo: redirectTo.toString() });
    }
  }
  // Acknowledges the request, never claims delivery or reveals account existence.
  return { status: "accepted" };
}

async function defaultDependencies(): Promise<InviteStaffDependencies> {
  const [{ createAdminClient }, { createServerClient }, { requireStaff }, { getAdminOrigin }] = await Promise.all([
    import("@/lib/supabase/admin"), import("@/lib/supabase/server"),
    import("@/lib/auth/access"), import("@/lib/auth/admin-origin"),
  ]);
  return { createAdminClient, createCallerClient: createServerClient, requireStaff, getAdminOrigin, randomBytes };
}
