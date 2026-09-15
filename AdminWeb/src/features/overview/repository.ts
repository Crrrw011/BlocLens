import "server-only";

import { randomUUID } from "node:crypto";

import type {
  MetricsRange,
  OperationalError,
  OverviewMetrics,
  RepositoryResult,
} from "../review/types";
import { metricsRangeSchema, overviewMetricsRowSchema } from "../review/schemas";
import type { RpcCaller } from "../review/repository";

export type OverviewRepositoryDependencies = {
  rpc: RpcCaller;
};

const RANGE_DAYS: Record<MetricsRange, number> = { "7d": 7, "30d": 30, "90d": 90 };

async function defaultRpc(
  functionName: string,
  parameters: Record<string, unknown>,
): Promise<{ data: unknown; error: { message: string } | null }> {
  const { createServerClient } = await import("@/lib/supabase/server");
  const client = await createServerClient();
  const { data, error } = await client.rpc(functionName, parameters);
  return { data, error: error ? { message: error.message } : null };
}

export async function getOverviewMetrics(
  range: unknown,
  dependencies?: OverviewRepositoryDependencies,
): Promise<RepositoryResult<OverviewMetrics>> {
  const rpc = dependencies?.rpc ?? defaultRpc;
  const parsedRange = metricsRangeSchema.safeParse(range);
  if (!parsedRange.success) {
    return { ok: false, error: { code: "invalid_input", traceId: randomUUID() } };
  }
  const end = new Date();
  const start = new Date(end.getTime() - RANGE_DAYS[parsedRange.data] * 86400000);

  let result: { data: unknown; error: { message: string } | null };
  try {
    result = await rpc("admin_overview_metrics", {
      range_start: start.toISOString(),
      range_end: end.toISOString(),
    });
  } catch {
    return { ok: false, error: { code: "upstream", traceId: randomUUID() } };
  }
  if (result.error) {
    return { ok: false, error: { code: "upstream", traceId: randomUUID() } };
  }
  const rows = Array.isArray(result.data) ? result.data : [];
  const parsed = overviewMetricsRowSchema.safeParse(rows[0]);
  if (!parsed.success) {
    const code: OperationalError["code"] =
      rows.length === 0 ? "not_found" : "upstream";
    return { ok: false, error: { code, traceId: randomUUID() } };
  }
  const row = parsed.data;
  return {
    ok: true,
    value: {
      pendingReports: row.pending_reports,
      severeReports: row.severe_reports,
      pendingCorrections: row.pending_corrections,
      duplicateRoutes: row.duplicate_routes,
      pendingClaims: row.pending_claims,
      hiddenContent: row.hidden_content,
      medianHandlingSeconds: row.median_handling_seconds,
      trend: row.trend.map((point) => ({
        day: point.day,
        opened: point.opened,
        resolved: point.resolved,
      })),
      distribution: row.distribution.map((slice) => ({
        kind: slice.kind,
        status: slice.status,
        count: slice.count,
      })),
      recentActions: row.recent_actions.map((action) => ({
        id: action.id,
        actionType: action.action_type,
        targetType: action.target_type,
        targetId: action.target_id,
        reason: action.reason,
        createdAt: action.created_at,
      })),
    },
  };
}
