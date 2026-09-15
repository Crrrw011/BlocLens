"use server";

import { redirect } from "next/navigation";
import { z } from "zod";

import type { ActionState } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";
import type { MergeConflict, MergeImpact } from "./types";

const copy = messages.en.climbingData;

const impactRowSchema = z.object({
  ok: z.boolean(),
  error_code: z.string().nullable(),
  impact: z
    .object({
      source: z.object({
        id: z.string().uuid(),
        colour: z.string().nullable(),
        gym_grade: z.number().nullable(),
        updated_at: z.string().min(1),
      }),
      canonical: z.object({
        id: z.string().uuid(),
        colour: z.string().nullable(),
        gym_grade: z.number().nullable(),
        updated_at: z.string().min(1),
      }),
      counts: z.record(z.string(), z.number()),
      conflicts: z.array(
        z.object({
          key: z.string().min(1),
          table: z.string().min(1),
          source_id: z.string().uuid(),
        }),
      ),
    })
    .nullable(),
});

export type MergeImpactResult =
  | { ok: true; value: MergeImpact }
  | { ok: false; errorCode: string };

export async function getMergeImpact(
  sourceId: string,
  canonicalId: string,
): Promise<MergeImpactResult> {
  if (!z.string().uuid().safeParse(sourceId).success) {
    return { ok: false, errorCode: "invalid" };
  }
  if (!z.string().uuid().safeParse(canonicalId).success) {
    return { ok: false, errorCode: "invalid" };
  }
  const supabase = await createServerClient();
  const { data, error } = await supabase.rpc("admin_route_merge_impact", {
    source_id: sourceId,
    canonical_id: canonicalId,
  });
  if (error) return { ok: false, errorCode: "upstream" };
  const parsed = z.array(impactRowSchema).safeParse(data ?? []);
  if (!parsed.success || parsed.data.length === 0) {
    return { ok: false, errorCode: "upstream" };
  }
  const row = parsed.data[0]!;
  if (!row.ok || !row.impact) {
    return { ok: false, errorCode: row.error_code ?? "upstream" };
  }
  return {
    ok: true,
    value: {
      source: {
        id: row.impact.source.id,
        colour: row.impact.source.colour,
        gymGrade: row.impact.source.gym_grade,
        updatedAt: row.impact.source.updated_at,
      },
      canonical: {
        id: row.impact.canonical.id,
        colour: row.impact.canonical.colour,
        gymGrade: row.impact.canonical.gym_grade,
        updatedAt: row.impact.canonical.updated_at,
      },
      counts: row.impact.counts,
      conflicts: row.impact.conflicts.map(
        (conflict): MergeConflict => ({
          key: conflict.key,
          table: conflict.table,
          sourceId: conflict.source_id,
        }),
      ),
    },
  };
}

export type MergeActionState =
  | ActionState
  | { status: "error"; message: string; conflict: true };

const resolutionsSchema = z
  .string()
  .transform((raw, ctx) => {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      ctx.addIssue({ code: "custom", message: "bad json" });
      return z.NEVER;
    }
    const result = z.record(z.string(), z.literal("skip")).safeParse(parsed);
    if (!result.success) {
      ctx.addIssue({ code: "custom", message: "bad resolutions" });
      return z.NEVER;
    }
    return result.data;
  });

const versionsSchema = z
  .string()
  .transform((raw, ctx) => {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      ctx.addIssue({ code: "custom", message: "bad json" });
      return z.NEVER;
    }
    const result = z
      .object({
        source: z.string().datetime({ offset: true }),
        canonical: z.string().datetime({ offset: true }),
      })
      .safeParse(parsed);
    if (!result.success) {
      ctx.addIssue({ code: "custom", message: "bad versions" });
      return z.NEVER;
    }
    return result.data;
  });

const mergeSchema = z.object({
  sourceId: z.string().uuid(),
  canonicalId: z.string().uuid(),
  resolutions: resolutionsSchema,
  reason: z.string().trim().min(1).max(2000),
  expectedVersions: versionsSchema,
  idempotencyKey: z.string().uuid(),
});

type OutcomeRow = { ok: boolean; error_code: string | null };

export async function mergeRoutes(
  _previous: MergeActionState,
  formData: FormData,
): Promise<MergeActionState> {
  const parsed = mergeSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.merge.invalidInput };
  }

  const supabase = await createServerClient();
  let data: unknown;
  try {
    const result = await supabase.rpc("admin_merge_routes", {
      source_id: parsed.data.sourceId,
      canonical_id: parsed.data.canonicalId,
      resolutions: parsed.data.resolutions,
      reason: parsed.data.reason,
      expected_versions: parsed.data.expectedVersions,
      idempotency_key: parsed.data.idempotencyKey,
    });
    if (result.error) return { status: "error", message: copy.merge.unavailable };
    data = result.data;
  } catch {
    return { status: "error", message: copy.merge.unavailable };
  }
  const row = (Array.isArray(data) ? data[0] : null) as OutcomeRow | null;
  if (!row) return { status: "error", message: copy.merge.unavailable };
  if (!row.ok && row.error_code === "conflict") {
    return { status: "error", message: copy.merge.conflictBody, conflict: true };
  }
  if (!row.ok && row.error_code === "unresolved_conflicts") {
    return { status: "error", message: copy.merge.unresolvedBody };
  }
  if (!row.ok) return { status: "error", message: copy.merge.unavailable };

  redirect(`/climbing-data/route/${parsed.data.canonicalId}`);
}
