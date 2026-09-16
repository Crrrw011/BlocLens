import "server-only";

import { randomUUID } from "node:crypto";
import { z } from "zod";

import type { AuditEvent, AuditPage } from "./export";

export type OperationalError = { code: "invalid_input" | "not_found" | "upstream"; traceId: string };

export type RepositoryResult<T> =
  | { ok: true; value: T }
  | { ok: false; error: OperationalError };

export type RpcCaller = (
  functionName: string,
  parameters: Record<string, unknown>,
) => Promise<{ data: unknown; error: { message: string } | null }>;

export const auditQuerySchema = z.object({
  actorId: z.string().uuid().nullable().default(null),
  action: z
    .string()
    .regex(/^[a-z0-9_.]{1,80}$/)
    .nullable()
    .default(null),
  targetType: z.string().max(80).nullable().default(null),
  outcome: z.enum(["succeeded", "rejected", "partially_failed", "failed"]).nullable().default(null),
  from: z.string().datetime({ offset: true }),
  to: z.string().datetime({ offset: true }),
  cursor: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}T.*\|[0-9a-f-]{36}$/)
    .nullable()
    .default(null),
  pageSize: z.number().int().min(1).max(100).default(20),
});

const auditRowSchema = z.object({
  id: z.string().uuid(),
  actor_id: z.string().uuid().nullable(),
  action_key: z.string().min(1),
  target_type: z.string().min(1),
  target_id: z.string().uuid().nullable(),
  reason: z.string(),
  outcome: z.string().min(1),
  before_summary: z.record(z.string(), z.unknown()),
  after_summary: z.record(z.string(), z.unknown()),
  created_at: z.string().min(1),
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

function mapEvent(row: z.infer<typeof auditRowSchema>): AuditEvent {
  return {
    id: row.id,
    actorId: row.actor_id,
    actionKey: row.action_key,
    targetType: row.target_type,
    targetId: row.target_id,
    reason: row.reason,
    outcome: row.outcome,
    beforeSummary: row.before_summary,
    afterSummary: row.after_summary,
    createdAt: row.created_at,
  };
}

export async function listAuditEvents(
  query: unknown,
  rpc: RpcCaller = defaultRpc,
): Promise<RepositoryResult<AuditPage>> {
  const parsed = auditQuerySchema.safeParse(query ?? {});
  if (!parsed.success) return failure("invalid_input");
  // The database owns range validity; a reversed window is a caller error.
  if (Date.parse(parsed.data.from) >= Date.parse(parsed.data.to)) {
    return failure("invalid_input");
  }

  let result: { data: unknown; error: { message: string } | null };
  try {
    result = await rpc("admin_list_audit", {
      actor_filter: parsed.data.actorId,
      action_filter: parsed.data.action,
      target_filter: parsed.data.targetType,
      outcome_filter: parsed.data.outcome,
      range_start: parsed.data.from,
      range_end: parsed.data.to,
      page_after: parsed.data.cursor,
      page_size: parsed.data.pageSize,
    });
  } catch {
    return failure("upstream");
  }
  if (result.error) return failure("upstream");

  const rows = z.array(auditRowSchema).safeParse(result.data ?? []);
  if (!rows.success) return failure("upstream");

  const items = rows.data.slice(0, parsed.data.pageSize).map(mapEvent);
  const last = items[items.length - 1];
  return {
    ok: true,
    value: {
      items,
      nextCursor:
        rows.data.length > parsed.data.pageSize && last
          ? `${last.createdAt}|${last.id}`
          : null,
    },
  };
}
