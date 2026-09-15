import { z } from "zod";

export const reviewKindSchema = z.enum([
  "content_report",
  "route_correction",
  "removal_report",
  "merge_suggestion",
]);

export const reviewQueueQuerySchema = z.object({
  status: z.enum(["pending", "resolved", "all"]).default("pending"),
  target: z
    .enum(["all", "route", "beta_link", "beta_comment", "route_photo"])
    .default("all"),
  q: z.string().max(200).default(""),
  cursor: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}T.*\|[0-9a-f-]{36}$/)
    .nullable()
    .default(null),
  pageSize: z.number().int().min(1).max(100).default(20),
});

const queueRowSchema = z.object({
  kind: reviewKindSchema,
  id: z.string().uuid(),
  status: z.string().min(1),
  severity: z.enum(["severe", "normal"]),
  route_id: z.string().uuid().nullable(),
  route_label: z.string().nullable(),
  gym_name: z.string().nullable(),
  target_type: z.string().min(1),
  target_id: z.string().uuid(),
  title: z.string(),
  summary: z.string(),
  created_at: z.string().min(1),
  updated_at: z.string().min(1),
});

export const reviewQueueRowsSchema = z.array(queueRowSchema);

const priorActionSchema = z.object({
  id: z.string().uuid(),
  action_type: z.string().min(1),
  reason: z.string(),
  created_at: z.string().min(1),
});

export const reviewItemRowSchema = queueRowSchema.extend({
  details: z.record(z.string(), z.unknown()),
  reporter_id: z.string().uuid().nullable(),
  reviewed_by: z.string().uuid().nullable(),
  reviewed_at: z.string().nullable(),
  prior_actions: z.array(priorActionSchema),
});

export const metricsRangeSchema = z.enum(["7d", "30d", "90d"]);

const trendPointSchema = z.object({
  day: z.string().min(1),
  opened: z.number(),
  resolved: z.number(),
});

const distributionSliceSchema = z.object({
  kind: z.string().min(1),
  status: z.string().min(1),
  count: z.number(),
});

const recentActionSchema = z.object({
  id: z.string().uuid(),
  action_type: z.string().min(1),
  target_type: z.string().nullable(),
  target_id: z.string().uuid().nullable(),
  reason: z.string(),
  created_at: z.string().min(1),
});

export const overviewMetricsRowSchema = z.object({
  pending_reports: z.number(),
  severe_reports: z.number(),
  pending_corrections: z.number(),
  duplicate_routes: z.number(),
  pending_claims: z.number(),
  hidden_content: z.number(),
  median_handling_seconds: z.number().nullable(),
  trend: z.array(trendPointSchema),
  distribution: z.array(distributionSliceSchema),
  recent_actions: z.array(recentActionSchema),
});
