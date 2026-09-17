"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import { en } from "@/lib/messages/en";
import type { EntityActionState } from "./actions";

const copy = en.climbingData.visibility;

const visibilitySchema = z.object({
  kind: z.enum(["wall_zone", "route_photo", "beta_link", "route_comment"]),
  id: z.string().uuid(),
  action: z.enum(["archive", "unarchive", "hide", "unhide"]),
  reason: z.string().trim().min(1).max(2000),
  expectedUpdatedAt: z.string().datetime({ offset: true }),
  idempotencyKey: z.string().uuid(),
});

type OutcomeRow = { ok: boolean; error_code: string | null };

async function callRpc(
  functionName: string,
  parameters: Record<string, unknown>,
): Promise<{ data: unknown; error: unknown }> {
  const { createServerClient } = await import("@/lib/supabase/server");
  const supabase = await createServerClient();
  try {
    return await supabase.rpc(functionName, parameters);
  } catch (error) {
    return { data: null, error };
  }
}

export async function setVisibility(
  _previous: EntityActionState,
  formData: FormData,
): Promise<EntityActionState> {
  const parsed = visibilitySchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.invalidInput };
  }

  const { data, error } = await callRpc("admin_set_visibility", {
    entity_kind: parsed.data.kind,
    entity_id: parsed.data.id,
    action: parsed.data.action,
    reason: parsed.data.reason,
    expected_updated_at: parsed.data.expectedUpdatedAt,
    idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) return { status: "error", message: copy.unavailable };
  const row = (Array.isArray(data) ? data[0] : null) as OutcomeRow | null;
  if (!row) return { status: "error", message: copy.unavailable };
  if (!row.ok && row.error_code === "conflict") {
    return { status: "error", message: copy.conflictBody, conflict: true };
  }
  if (!row.ok) return { status: "error", message: copy.unavailable };

  revalidatePath("/climbing-data");
  revalidatePath("/overview");
  return { status: "success" };
}
