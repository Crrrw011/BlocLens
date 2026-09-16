"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import type { ActionState } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

const copy = messages.en.people.claims;

export type ClaimActionState =
  | ActionState
  | { status: "error"; message: string; conflict: true };

const decisionSchema = z.object({
  claimId: z.string().uuid(),
  decision: z.enum(["approved", "rejected"]),
  reviewNote: z.string().trim().min(1).max(1000),
  expectedUpdatedAt: z.string().datetime({ offset: true }),
  idempotencyKey: z.string().uuid(),
});

type OutcomeRow = { ok: boolean; error_code: string | null };

export async function decideClaim(
  _previous: ClaimActionState,
  formData: FormData,
): Promise<ClaimActionState> {
  const parsed = decisionSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.invalidInput };
  }

  const supabase = await createServerClient();
  let data: unknown;
  try {
    const result = await supabase.rpc("admin_decide_gym_claim", {
      claim_id: parsed.data.claimId,
      decision: parsed.data.decision,
      review_note: parsed.data.reviewNote,
      expected_updated_at: parsed.data.expectedUpdatedAt,
      idempotency_key: parsed.data.idempotencyKey,
    });
    if (result.error) return { status: "error", message: copy.unavailable };
    data = result.data;
  } catch {
    return { status: "error", message: copy.unavailable };
  }
  const row = (Array.isArray(data) ? data[0] : null) as OutcomeRow | null;
  if (!row) return { status: "error", message: copy.unavailable };
  if (!row.ok && row.error_code === "conflict") {
    return { status: "error", message: copy.conflictBody, conflict: true };
  }
  if (!row.ok) return { status: "error", message: copy.unavailable };

  revalidatePath("/people/claims");
  revalidatePath("/overview");
  return { status: "success" };
}
