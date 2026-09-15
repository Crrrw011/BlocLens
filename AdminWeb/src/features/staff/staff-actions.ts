"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import type { ActionState } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

const copy = messages.en.people.staff;

export type StaffActionState =
  | ActionState
  | { status: "error"; message: string; conflict: true };

type OutcomeRow = { ok: boolean; error_code: string | null };

async function callRpc(
  functionName: string,
  parameters: Record<string, unknown>,
): Promise<{ data: unknown; error: unknown }> {
  const supabase = await createServerClient();
  try {
    return await supabase.rpc(functionName, parameters);
  } catch (error) {
    return { data: null, error };
  }
}

function mapOutcome(
  data: unknown,
  error: unknown,
  failureMessage: string,
): StaffActionState {
  if (error) return { status: "error", message: copy.unavailable };
  const row = (Array.isArray(data) ? data[0] : null) as OutcomeRow | null;
  if (!row) return { status: "error", message: copy.unavailable };
  if (!row.ok) return { status: "error", message: failureMessage };
  revalidatePath("/staff");
  revalidatePath("/people");
  return { status: "success" };
}

const revokeSchema = z.object({
  invitationId: z.string().uuid(),
  reason: z.string().trim().min(1).max(2000),
  idempotencyKey: z.string().uuid(),
});

export async function revokeInvitation(
  _previous: StaffActionState,
  formData: FormData,
): Promise<StaffActionState> {
  const parsed = revokeSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.invalidInput };
  }
  const { data, error } = await callRpc("admin_revoke_staff_invitation", {
    invitation_id: parsed.data.invitationId,
    reason: parsed.data.reason,
    idempotency_key: parsed.data.idempotencyKey,
  });
  return mapOutcome(data, error, copy.unavailable);
}

const accessSchema = z.object({
  targetUserId: z.string().uuid(),
  makeActive: z.enum(["true", "false"]).transform((value) => value === "true"),
  reason: z.string().trim().min(1).max(2000),
  idempotencyKey: z.string().uuid(),
});

export async function setStaffActive(
  _previous: StaffActionState,
  formData: FormData,
): Promise<StaffActionState> {
  const parsed = accessSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.invalidInput };
  }
  const { data, error } = await callRpc("admin_set_staff_active", {
    target_user_id: parsed.data.targetUserId,
    make_active: parsed.data.makeActive,
    reason: parsed.data.reason,
    idempotency_key: parsed.data.idempotencyKey,
  });
  return mapOutcome(data, error, copy.unavailable);
}
