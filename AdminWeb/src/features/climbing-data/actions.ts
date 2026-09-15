"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import type { ActionState } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

const copy = messages.en.climbingData;

function optionalGrade(field: string) {
  return z
    .string()
    .transform((raw, ctx) => {
      if (raw.trim() === "") return undefined;
      const value = Number(raw);
      if (!Number.isInteger(value) || value < -1 || value > 17) {
        ctx.addIssue({ code: "custom", message: `bad ${field}` });
        return z.NEVER;
      }
      return value;
    })
    .optional();
}

const updateSchema = z.object({
  kind: z.literal("route"),
  id: z.string().uuid(),
  colour: z.string().trim().min(1).max(80),
  gym_grade: optionalGrade("gym_grade"),
  terrain: z.enum(["slab", "vertical", "overhang", "roof", "cave", "mixed"]),
  subjective_grade: optionalGrade("subjective_grade"),
  reason: z.string().trim().min(1).max(2000),
  expectedUpdatedAt: z.string().datetime({ offset: true }),
  idempotencyKey: z.string().uuid(),
});

export type EntityActionState =
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

export async function updateEntity(
  _previous: EntityActionState,
  formData: FormData,
): Promise<EntityActionState> {
  const parsed = updateSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.edit.invalidInput };
  }

  const { data, error } = await callRpc("admin_update_entity", {
    entity_kind: parsed.data.kind,
    entity_id: parsed.data.id,
    patch: {
      colour: parsed.data.colour,
      ...(parsed.data.gym_grade === undefined ? {} : { gym_grade: parsed.data.gym_grade }),
      terrain: parsed.data.terrain,
      ...(parsed.data.subjective_grade === undefined
        ? {}
        : { subjective_grade: parsed.data.subjective_grade }),
    },
    reason: parsed.data.reason,
    expected_updated_at: parsed.data.expectedUpdatedAt,
    idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) return { status: "error", message: copy.edit.unavailable };
  const row = (Array.isArray(data) ? data[0] : null) as OutcomeRow | null;
  if (!row) return { status: "error", message: copy.edit.unavailable };
  if (!row.ok && row.error_code === "conflict") {
    return { status: "error", message: copy.edit.conflictBody, conflict: true };
  }
  if (!row.ok) return { status: "error", message: copy.edit.unavailable };

  revalidatePath("/climbing-data");
  return { status: "success" };
}

const lifecycleSchema = z.object({
  routeId: z.string().uuid(),
  action: z.enum(["archive", "unarchive", "hide", "unhide"]),
  reason: z.string().trim().min(1).max(2000),
  expectedUpdatedAt: z.string().datetime({ offset: true }),
  idempotencyKey: z.string().uuid(),
});

export async function changeLifecycle(
  _previous: EntityActionState,
  formData: FormData,
): Promise<EntityActionState> {
  const parsed = lifecycleSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.edit.invalidInput };
  }

  const { data, error } = await callRpc("admin_change_lifecycle", {
    route_id: parsed.data.routeId,
    action: parsed.data.action,
    reason: parsed.data.reason,
    expected_updated_at: parsed.data.expectedUpdatedAt,
    idempotency_key: parsed.data.idempotencyKey,
  });
  if (error) return { status: "error", message: copy.lifecycle.unavailable };
  const row = (Array.isArray(data) ? data[0] : null) as OutcomeRow | null;
  if (!row) return { status: "error", message: copy.lifecycle.unavailable };
  if (!row.ok && row.error_code === "conflict") {
    return { status: "error", message: copy.lifecycle.conflictBody, conflict: true };
  }
  if (!row.ok) return { status: "error", message: copy.lifecycle.unavailable };

  revalidatePath("/climbing-data");
  revalidatePath("/overview");
  revalidatePath("/review");
  return { status: "success" };
}
