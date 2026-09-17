import Link from "next/link";

import { EmptyState } from "@/components/ui/empty-state";
import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { getOverviewMetrics } from "@/features/overview/repository";
import { listReviewQueue } from "@/features/review/repository";
import type { MetricsRange } from "@/features/review/types";
import { MetricsGrid } from "@/features/overview/metrics-grid";
import { PriorityTable } from "@/features/overview/priority-table";
import { QueueDistribution } from "@/features/overview/queue-distribution";
import { ReviewTrend } from "@/features/overview/review-trend";

const RANGES: MetricsRange[] = ["7d", "30d", "90d"];

function parseRange(value: unknown): MetricsRange {
  return value === "7d" || value === "90d" || value === "30d"
    ? (value as MetricsRange)
    : "30d";
}

function formatHandling(seconds: number | null): string | null {
  if (seconds === null) return null;
  if (seconds < 3600) return `${Math.round(seconds / 60)}m`;
  if (seconds < 86400) return `${Math.round(seconds / 3600)}h`;
  return `${Math.round(seconds / 86400)}d`;
}

export default async function OverviewPage({
  searchParams,
}: Readonly<{ searchParams?: Promise<Record<string, string | string[] | undefined>> }>) {
  const access = await requireStaff();
  const params = (await searchParams) ?? {};
  const raw = Array.isArray(params.range) ? params.range[0] : params.range;
  const range = parseRange(raw);

  const [metricsResult, priorityResult] = await Promise.all([
    getOverviewMetrics(range),
    listReviewQueue({ status: "pending", pageSize: 5 }),
  ]);
  if (!metricsResult.ok || !priorityResult.ok) {
    throw new Error("Overview metrics are unavailable");
  }
  const metrics = metricsResult.value;
  const isEmpty =
    metrics.pendingReports === 0 &&
    metrics.pendingCorrections === 0 &&
    metrics.duplicateRoutes === 0 &&
    metrics.pendingClaims === 0 &&
    metrics.hiddenContent === 0;

  const handling = formatHandling(metrics.medianHandlingSeconds);

  return (
    <section className="portal-page" aria-label={en.shell.overviewWorkspace}>
      <div className="row-head">
        <div>
          <h1>{en.overview.title}</h1>
          <div className="sub">
            {en.shell.roles[access.role]} · {en.overview.subtitle}
          </div>
        </div>
      </div>
      <nav className="overview-range" aria-label={en.overview.rangeLabel}>
        {RANGES.map((option) => (
          <Link
            key={option}
            href={`/overview?range=${option}`}
            aria-current={option === range ? "page" : undefined}
          >
            {en.overview.ranges[option]}
          </Link>
        ))}
      </nav>

      {isEmpty ? (
        <EmptyState
          title={en.overview.empty.title}
          body={en.overview.empty.body}
          action={<Link href="/review?status=pending">{en.overview.metrics.viewQueue}</Link>}
        />
      ) : (
        <>
          <MetricsGrid
            pendingReports={metrics.pendingReports}
            severeReports={metrics.severeReports}
            pendingCorrections={metrics.pendingCorrections}
            duplicateRoutes={metrics.duplicateRoutes}
            pendingClaims={metrics.pendingClaims}
            hiddenContent={metrics.hiddenContent}
          />
          {handling ? (
            <p className="overview-handling">
              {en.overview.handling.label}: {handling}
            </p>
          ) : null}
          <div className="overview-panels">
            <ReviewTrend points={metrics.trend} />
            <QueueDistribution slices={metrics.distribution} />
          </div>
          <PriorityTable items={priorityResult.value.items} />
        </>
      )}
    </section>
  );
}
