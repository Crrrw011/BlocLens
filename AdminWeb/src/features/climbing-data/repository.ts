import "server-only";

import { randomUUID } from "node:crypto";
import { z } from "zod";

import type {
  EntityDetail,
  EntityKind,
  EntityListItem,
  EntityListQuery,
} from "./types";

export type OperationalError = { code: "invalid_input" | "not_found" | "upstream"; traceId: string };

export type RepositoryResult<T> =
  | { ok: true; value: T }
  | { ok: false; error: OperationalError };

export type CursorPage<T> = { items: T[]; nextCursor: string | null };

export type RpcCaller = (
  functionName: string,
  parameters: Record<string, unknown>,
) => Promise<{ data: unknown; error: { message: string } | null }>;

const entityKindSchema = z.enum([
  "gym",
  "wall_zone",
  "route",
  "reset",
  "route_photo",
  "beta_link",
  "route_comment",
]);

const entityQuerySchema = z.object({
  kind: entityKindSchema,
  status: z.string().trim().min(1).max(40).default("all"),
  q: z.string().max(200).default(""),
  gymId: z.string().uuid().nullable().default(null),
  cursor: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}T.*\|[0-9a-f-]{36}$/)
    .nullable()
    .default(null),
  pageSize: z.number().int().min(1).max(100).default(20),
});

const listRowSchema = z.object({
  kind: entityKindSchema,
  id: z.string().uuid(),
  status: z.string().min(1),
  title: z.string(),
  subtitle: z.string().nullable(),
  moderation: z.string().nullable(),
  dependent_counts: z.record(z.string(), z.number()),
  updated_at: z.string().min(1),
  created_at: z.string().min(1),
});

const historyEntrySchema = z.object({
  id: z.string().uuid(),
  action_type: z.string().min(1),
  reason: z.string(),
  created_at: z.string().min(1),
});

const detailRowSchema = listRowSchema.extend({
  details: z.record(z.string(), z.unknown()),
  related: z.record(z.string(), z.unknown()),
  moderation_history: z.array(historyEntrySchema),
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

function mapItem(row: z.infer<typeof listRowSchema>): EntityListItem {
  return {
    kind: row.kind,
    id: row.id,
    status: row.status,
    title: row.title,
    subtitle: row.subtitle,
    moderation: row.moderation,
    dependentCounts: row.dependent_counts,
    updatedAt: row.updated_at,
    createdAt: row.created_at,
  };
}

export async function listEntities(
  query: unknown,
  rpc: RpcCaller = defaultRpc,
): Promise<RepositoryResult<CursorPage<EntityListItem>>> {
  const parsed = entityQuerySchema.safeParse(query ?? {});
  if (!parsed.success) return failure("invalid_input");
  const input: EntityListQuery & { kind: EntityKind } = parsed.data;

  let result: { data: unknown; error: { message: string } | null };
  try {
    result = await rpc("admin_list_entities", {
      entity_kind: input.kind,
      status_filter: input.status,
      search_text: input.q === "" ? null : input.q,
      gym_id: input.gymId,
      page_after: input.cursor,
      page_size: input.pageSize,
    });
  } catch {
    return failure("upstream");
  }
  if (result.error) return failure("upstream");

  const rows = z.array(listRowSchema).safeParse(result.data ?? []);
  if (!rows.success) return failure("upstream");

  const items = rows.data.slice(0, input.pageSize).map(mapItem);
  const last = items[items.length - 1];
  return {
    ok: true,
    value: {
      items,
      nextCursor:
        rows.data.length > input.pageSize && last
          ? `${last.updatedAt}|${last.id}`
          : null,
    },
  };
}

export async function getEntityDetail(
  ref: unknown,
  rpc: RpcCaller = defaultRpc,
): Promise<RepositoryResult<EntityDetail>> {
  const parsedKind = entityKindSchema.safeParse(
    typeof ref === "object" && ref !== null
      ? (ref as Record<string, unknown>).kind
      : undefined,
  );
  const parsedId =
    typeof ref === "object" && ref !== null ? (ref as { id?: unknown }).id : undefined;
  if (!parsedKind.success || typeof parsedId !== "string") {
    return failure("invalid_input");
  }

  let result: { data: unknown; error: { message: string } | null };
  try {
    result = await rpc("admin_entity_detail", {
      entity_kind: parsedKind.data,
      entity_id: parsedId,
    });
  } catch {
    return failure("upstream");
  }
  if (result.error) return failure("upstream");

  const rows = Array.isArray(result.data) ? result.data : [];
  if (rows.length === 0) return failure("not_found");
  const parsed = detailRowSchema.safeParse(rows[0]);
  if (!parsed.success) return failure("upstream");
  const row = parsed.data;
  return {
    ok: true,
    value: {
      ...mapItem(row),
      details: row.details,
      related: row.related,
      moderationHistory: row.moderation_history.map((entry) => ({
        id: entry.id,
        actionType: entry.action_type,
        reason: entry.reason,
        createdAt: entry.created_at,
      })),
    },
  };
}
