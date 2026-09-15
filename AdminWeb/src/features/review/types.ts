export type ReviewKind =
  | "content_report"
  | "route_correction"
  | "removal_report"
  | "merge_suggestion";

export type ReviewDecision =
  | "dismiss"
  | "escalate"
  | "hide"
  | "restore"
  | "accept_correction"
  | "reject_correction";

export type ReviewRef = { kind: ReviewKind; id: string };

export type CursorPage<T> = { items: T[]; nextCursor: string | null };

export type ReviewStatusFilter = "pending" | "resolved" | "all";
export type ReviewTargetFilter =
  | "all"
  | "route"
  | "beta_link"
  | "beta_comment"
  | "route_photo";

export type ReviewQueueQuery = {
  status: ReviewStatusFilter;
  kind: ReviewKind | "all";
  severity: "all" | "severe" | "normal";
  target: ReviewTargetFilter;
  q: string;
  cursor: string | null;
  pageSize: number;
};

export type ReviewQueueItem = {
  kind: ReviewKind;
  id: string;
  status: string;
  severity: "severe" | "normal";
  routeId: string | null;
  routeLabel: string | null;
  gymName: string | null;
  targetType: string;
  targetId: string;
  title: string;
  summary: string;
  createdAt: string;
  updatedAt: string;
};

export type PriorAction = {
  id: string;
  actionType: string;
  reason: string;
  createdAt: string;
};

export type ReviewItemDetail = ReviewQueueItem & {
  details: Record<string, unknown>;
  reporterId: string | null;
  reviewedBy: string | null;
  reviewedAt: string | null;
  priorActions: PriorAction[];
};

export type TrendPoint = { day: string; opened: number; resolved: number };
export type DistributionSlice = { kind: string; status: string; count: number };
export type RecentAction = {
  id: string;
  actionType: string;
  targetType: string | null;
  targetId: string | null;
  reason: string;
  createdAt: string;
};

export type OverviewMetrics = {
  pendingReports: number;
  severeReports: number;
  pendingCorrections: number;
  duplicateRoutes: number;
  pendingClaims: number;
  hiddenContent: number;
  medianHandlingSeconds: number | null;
  trend: TrendPoint[];
  distribution: DistributionSlice[];
  recentActions: RecentAction[];
};

export type MetricsRange = "7d" | "30d" | "90d";

export type OperationalErrorCode =
  | "invalid_input"
  | "not_found"
  | "upstream"
  | "unknown";

export type OperationalError = { code: OperationalErrorCode; traceId: string };

export type RepositoryResult<T> =
  | { ok: true; value: T }
  | { ok: false; error: OperationalError };
