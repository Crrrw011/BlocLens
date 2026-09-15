"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import type { ActionState } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

const copy = messages.en.review.decisions;

const decisionSchema = z.object({
  kind: z.enum(["content_report", "route_correction", "removal_report", "merge_suggestion"]),
  id: z.string().uuid(),
  decision: z.enum([
    "dismiss",
    "escalate",
    "hide",
    "restore",
    "accept_correction",
    "reject_correction",
  ]),
  reason: z.string().trim().min(1).max(2000),
  expectedUpdatedAt: z.string().datetime({ offset: true }),
  idempotencyKey: z.string().uuid(),
});

export type DecisionState =
  | ActionState
  | { status: "error"; message: string; conflict: true };

type DecisionRow = {
  ok: boolean;
  error_code: string | null;
};

export async function decideReview(
  _previous: DecisionState,
  formData: FormData,
): Promise<DecisionState> {
  const parsed = decisionSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.invalidInput };
  }

  const supabase = await createServerClient();
  let data: unknown;
  try {
    const result = await supabase.rpc("admin_decide_review", {
      item_kind: parsed.data.kind,
      item_id: parsed.data.id,
      decision: parsed.data.decision,
      reason: parsed.data.reason,
      expected_updated_at: parsed.data.expectedUpdatedAt,
      idempotency_key: parsed.data.idempotencyKey,
    });
    if (result.error) {
      return { status: "error", message: copy.unavailable };
    }
    data = result.data;
  } catch {
    return { status: "error", message: copy.unavailable };
  }
  const row = (Array.isArray(data) ? data[0] : null) as DecisionRow | null;
  if (!row) {
    return { status: "error", message: copy.unavailable };
  }
  if (!row.ok && row.error_code === "conflict") {
    return { status: "error", message: copy.conflictBody, conflict: true };
  }
  if (!row.ok) {
    return { status: "error", message: copy.unavailable };
  }

  revalidatePath("/overview");
  revalidatePath("/review");
  return { status: "success" };
}
