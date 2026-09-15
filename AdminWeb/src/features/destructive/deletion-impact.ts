import "server-only";

import { z } from "zod";

import type { DeletionImpact } from "../climbing-data/types";

const impactRowSchema = z.object({
  eligible: z.boolean(),
  blockers: z.array(z.string()),
  dependent_counts: z.record(z.string(), z.number()),
  storage_paths: z.array(z.string()),
  alternative: z.enum(["archive", "merge", "anonymise"]).nullable(),
});

export type DeletionTargetType = "route" | "route_photo" | "beta_link" | "route_comment";

export async function getDeletionImpact(
  targetType: string,
  targetId: string,
): Promise<DeletionImpact | null> {
  if (!z.enum(["route", "route_photo", "beta_link", "route_comment"]).safeParse(targetType).success) {
    return null;
  }
  if (!z.string().uuid().safeParse(targetId).success) return null;
  const { createServerClient } = await import("@/lib/supabase/server");
  const client = await createServerClient();
  const { data, error } = await client.rpc("admin_deletion_impact", {
    target_type: targetType,
    target_id: targetId,
  });
  if (error) return null;
  const rows = z.array(impactRowSchema).safeParse(data ?? []);
  if (!rows.success || rows.data.length === 0) return null;
  const row = rows.data[0]!;
  return {
    eligible: row.eligible,
    blockers: row.blockers,
    dependentCounts: row.dependent_counts,
    storagePaths: row.storage_paths,
    alternative: row.alternative,
  };
}
