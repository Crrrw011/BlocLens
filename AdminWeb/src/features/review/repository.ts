import "server-only";

import { randomUUID } from "node:crypto";

import type {
  CursorPage,
  OperationalError,
  RepositoryResult,
  ReviewItemDetail,
  ReviewQueueItem,
  ReviewQueueQuery,
  ReviewRef,
} from "./types";
import {
  reviewItemRowSchema,
  reviewKindSchema,
  reviewQueueQuerySchema,
  reviewQueueRowsSchema,
} from "./schemas";

export type RpcCaller = (
  functionName: string,
  parameters: Record<string, unknown>,
) => Promise<{ data: unknown; error: { message: string } | null }>;

export type ReviewRepositoryDependencies = {
  rpc: RpcCaller;
};

function failure(code: OperationalError["code"]): { ok: false; error: OperationalError } {
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

function defaultDependencies(): ReviewRepositoryDependencies {
  return { rpc: defaultRpc };
}

function mapQueueItem(row: {
  kind: ReviewQueueItem["kind"];
  id: string;
  status: string;
  severity: ReviewQueueItem["severity"];
  route_id: string | null;
  route_label: string | null;
  gym_name: string | null;
  target_type: string;
  target_id: string;
  title: string;
  summary: string;
  created_at: string;
  updated_at: string;
}): ReviewQueueItem {
  return {
    kind: row.kind,
    id: row.id,
    status: row.status,
    severity: row.severity,
    routeId: row.route_id,
    routeLabel: row.route_label,
    gymName: row.gym_name,
    targetType: row.target_type,
    targetId: row.target_id,
    title: row.title,
    summary: row.summary,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function encodeCursor(createdAt: string, id: string): string {
  return `${createdAt}|${id}`;
}

export async function listReviewQueue(
  query: unknown,
  dependencies?: ReviewRepositoryDependencies,
): Promise<RepositoryResult<CursorPage<ReviewQueueItem>>> {
  const deps = dependencies ?? defaultDependencies();
  const parsed = reviewQueueQuerySchema.safeParse(query ?? {});
  if (!parsed.success) return failure("invalid_input");
  const input: ReviewQueueQuery = parsed.data;

  let result: { data: unknown; error: { message: string } | null };
  try {
    result = await deps.rpc("admin_review_queue", {
      status_filter: input.status,
      target_filter: input.target,
      search_text: input.q === "" ? null : input.q,
      page_after: input.cursor,
      page_size: input.pageSize,
      kind_filter: input.kind,
      severity_filter: input.severity,
    });
  } catch {
    return failure("upstream");
  }
  if (result.error) return failure("upstream");

  const rows = reviewQueueRowsSchema.safeParse(result.data ?? []);
  if (!rows.success) return failure("upstream");

  // The projection returns one lookahead row past the requested size.
  const items = rows.data.slice(0, input.pageSize).map(mapQueueItem);
  const last = items[items.length - 1];
  return {
    ok: true,
    value: {
      items,
      nextCursor:
        rows.data.length > input.pageSize && last
          ? encodeCursor(last.createdAt, last.id)
          : null,
    },
  };
}

export async function getReviewItem(
  ref: unknown,
  dependencies?: ReviewRepositoryDependencies,
): Promise<RepositoryResult<ReviewItemDetail>> {
  const deps = dependencies ?? defaultDependencies();
  const parsedKind = reviewKindSchema.safeParse(
    typeof ref === "object" && ref !== null
      ? (ref as Record<string, unknown>).kind
      : undefined,
  );
  const parsedId =
    typeof ref === "object" && ref !== null
      ? (ref as { id?: unknown }).id
      : undefined;
  if (!parsedKind.success || typeof parsedId !== "string") {
    return failure("invalid_input");
  }
  const input: ReviewRef = { kind: parsedKind.data, id: parsedId };

  let result: { data: unknown; error: { message: string } | null };
  try {
    result = await deps.rpc("admin_review_item", {
      item_kind: input.kind,
      item_id: input.id,
    });
  } catch {
    return failure("upstream");
  }
  if (result.error) return failure("upstream");

  const rows = Array.isArray(result.data) ? result.data : [];
  if (rows.length === 0) return failure("not_found");
  const parsed = reviewItemRowSchema.safeParse(rows[0]);
  if (!parsed.success) return failure("upstream");
  const row = parsed.data;
  return {
    ok: true,
    value: {
      ...mapQueueItem(row),
      details: row.details,
      reporterId: row.reporter_id,
      reviewedBy: row.reviewed_by,
      reviewedAt: row.reviewed_at,
      priorActions: row.prior_actions.map((action) => ({
        id: action.id,
        actionType: action.action_type,
        reason: action.reason,
        createdAt: action.created_at,
      })),
    },
  };
}
