"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import type { ActionState } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

const copy = messages.en.people.penalties;

export type PenaltyActionState =
  | ActionState
  | { status: "error"; message: string; conflict: true };

type OutcomeRow = { ok: boolean; error_code: string | null };

const penaltySchema = z
  .object({
    userId: z.string().uuid(),
    kind: z.enum(["publishing_restriction", "timed_suspension", "permanent_ban"]),
    endsAt: z.preprocess(
      (value) => (value === "" ? undefined : value),
      z.string().datetime({ offset: true }).optional(),
    ),
    reason: z.string().trim().min(1).max(1000),
    idempotencyKey: z.string().uuid(),
  })
  .refine((input) => input.kind !== "timed_suspension" || input.endsAt !== undefined, {
    message: "suspension needs an end",
  });

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
  coordinate: { revalidate: string[] },
): PenaltyActionState {
  if (error) return { status: "error", message: copy.unavailable };
  const row = (Array.isArray(data) ? data[0] : null) as OutcomeRow | null;
  if (!row) return { status: "error", message: copy.unavailable };
  if (!row.ok && row.error_code === "already_active") {
    return { status: "error", message: copy.alreadyActive };
  }
  if (!row.ok) return { status: "error", message: copy.unavailable };
  for (const path of coordinate.revalidate) revalidatePath(path);
  return { status: "success" };
}

export async function applyPenalty(
  _previous: PenaltyActionState,
  formData: FormData,
): Promise<PenaltyActionState> {
  const parsed = penaltySchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.invalidInput };
  }
  const { data, error } = await callRpc("admin_apply_user_penalty", {
    target_user_id: parsed.data.userId,
    penalty_kind: parsed.data.kind,
    ends_at: parsed.data.endsAt ?? null,
    reason: parsed.data.reason,
    idempotency_key: parsed.data.idempotencyKey,
  });
  return mapOutcome(data, error, { revalidate: ["/people", "/overview"] });
}

const reversalSchema = z.object({
  actionId: z.string().uuid(),
  reason: z.string().trim().min(1).max(1000),
  idempotencyKey: z.string().uuid(),
});

export async function reversePenalty(
  _previous: PenaltyActionState,
  formData: FormData,
): Promise<PenaltyActionState> {
  const parsed = reversalSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.invalidInput };
  }
  const { data, error } = await callRpc("admin_reverse_user_penalty", {
    penalty_action_id: parsed.data.actionId,
    reason: parsed.data.reason,
    idempotency_key: parsed.data.idempotencyKey,
  });
  return mapOutcome(data, error, { revalidate: ["/people", "/overview"] });
}
