"use server";

import { redirect } from "next/navigation";
import { z } from "zod";

import { type ActionState, requireStaff } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

const copy = messages.en.climbingData.deletion;

const deleteSchema = z.object({
  targetType: z.enum(["route", "route_photo", "beta_link", "route_comment"]),
  targetId: z.string().uuid(),
  reason: z.string().trim().min(1).max(2000),
  expectedUpdatedAt: z.string().datetime({ offset: true }),
  idempotencyKey: z.string().uuid(),
  confirmation: z.literal("DELETE"),
});

export type DeleteActionState =
  | ActionState
  | { status: "error"; message: string; conflict: true };

type OutcomeRow = { ok: boolean; error_code: string | null };

const KIND_PATH: Record<string, string> = {
  route: "route",
  route_photo: "route_photo",
  beta_link: "beta_link",
  route_comment: "route_comment",
};

export async function permanentDelete(
  _previous: DeleteActionState,
  formData: FormData,
): Promise<DeleteActionState> {
  const access = await requireStaff();
  if (access.role !== "admin") {
    return { status: "error", message: copy.forbidden };
  }

  const parsed = deleteSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.invalidInput };
  }

  const supabase = await createServerClient();
  const { data: impactRows, error: impactError } = await supabase.rpc(
    "admin_deletion_impact",
    { target_type: parsed.data.targetType, target_id: parsed.data.targetId },
  );
  const impact = (Array.isArray(impactRows) ? impactRows[0] : null) as {
    eligible: boolean;
    blockers: string[];
    storage_paths: string[];
  } | null;
  if (impactError || !impact) {
    return { status: "error", message: copy.unavailable };
  }
  if (!impact.eligible) {
    return { status: "error", message: `${copy.blocked} (${impact.blockers.join(", ")})` };
  }

  // Ordered server workflow: files first, database second. Storage failures
  // never reach the deletion transaction, so success is never misreported.
  if (impact.storage_paths.length > 0) {
    const bucket = process.env.ROUTE_PHOTOS_BUCKET;
    if (bucket) {
      const { createAdminClient } = await import("@/lib/supabase/admin");
      const admin = createAdminClient();
      const { error: storageError } = await admin.storage
        .from(bucket)
        .remove(impact.storage_paths);
      if (storageError) {
        return {
          status: "error",
          message: `${copy.storageFailed} (${impact.storage_paths.join(", ")})`,
        };
      }
    }
    // Without a configured bucket, storage paths are external references;
    // the database row is the only deletable record.
  }

  let data: unknown;
  try {
    const result = await supabase.rpc("admin_permanently_delete", {
      target_type: parsed.data.targetType,
      target_id: parsed.data.targetId,
      reason: parsed.data.reason,
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
  if (!row.ok && row.error_code === "blocked") {
    return { status: "error", message: copy.blocked };
  }
  if (!row.ok) return { status: "error", message: copy.unavailable };

  redirect(`/climbing-data/${KIND_PATH[parsed.data.targetType]}`);
}
