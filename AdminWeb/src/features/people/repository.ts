import "server-only";

import { randomUUID } from "node:crypto";
import { z } from "zod";

import type { UserSummary } from "./types";

export type OperationalError = { code: "invalid_input" | "not_found" | "upstream"; traceId: string };

export type RepositoryResult<T> =
  | { ok: true; value: T }
  | { ok: false; error: OperationalError };

export type RpcCaller = (
  functionName: string,
  parameters: Record<string, unknown>,
) => Promise<{ data: unknown; error: { message: string } | null }>;

const restrictionSchema = z.object({
  id: z.string().uuid(),
  kind: z.enum(["publishing_restriction", "timed_suspension", "permanent_ban"]),
  reason: z.string(),
  ends_at: z.string().nullable(),
  created_at: z.string().min(1),
});

const historyEntrySchema = z.object({
  id: z.string().uuid(),
  action_type: z.string().min(1),
  reason: z.string(),
  created_at: z.string().min(1),
});

const summaryRowSchema = z.object({
  user_id: z.string().uuid(),
  username: z.string().min(1),
  member_since: z.string().min(1),
  staff_role: z.string().nullable(),
  active_restrictions: z.array(restrictionSchema),
  recent_actions: z.array(historyEntrySchema),
  contribution_counts: z.record(z.string(), z.number()),
});

function failure(
  code: OperationalError["code"],
): { ok: false; error: OperationalError } {
  return { ok: false, error: { code, traceId: randomUUID() } };
}

async function defaultRpc(
  functionName: string,
  parameters: Record<string, unknown>,
): Promise<{ data: unknown; error: { message: string } | null }> {
  const { createServerClient } = await import("@/lib/supabase/server");
  const client = await createServerClient();
  const { data, error } = await client.rpc(functionName, parameters);
  return { data, error: error ? { message: error.message } : null };
}

export async function getUserSummary(
  userId: unknown,
  rpc: RpcCaller = defaultRpc,
): Promise<RepositoryResult<UserSummary>> {
  if (typeof userId !== "string" || !z.string().uuid().safeParse(userId).success) {
    return failure("invalid_input");
  }

  let result: { data: unknown; error: { message: string } | null };
  try {
    result = await rpc("admin_user_summary", { target_user_id: userId });
  } catch {
    return failure("upstream");
  }
  if (result.error) return failure("upstream");

  const rows = Array.isArray(result.data) ? result.data : [];
  if (rows.length === 0) return failure("not_found");
  const parsed = summaryRowSchema.safeParse(rows[0]);
  if (!parsed.success) return failure("upstream");
  const row = parsed.data;
  return {
    ok: true,
    value: {
      userId: row.user_id,
      username: row.username,
      memberSince: row.member_since,
      staffRole: row.staff_role,
      activeRestrictions: row.active_restrictions.map((restriction) => ({
        id: restriction.id,
        kind: restriction.kind,
        reason: restriction.reason,
        endsAt: restriction.ends_at,
        createdAt: restriction.created_at,
      })),
      recentActions: row.recent_actions.map((entry) => ({
        id: entry.id,
        actionType: entry.action_type,
        reason: entry.reason,
        createdAt: entry.created_at,
      })),
      contributionCounts: row.contribution_counts,
    },
  };
}
