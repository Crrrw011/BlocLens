import Link from "next/link";

import { en } from "@/lib/messages/en";

const copy = en.overview.metrics;

type Metric = Readonly<{
  label: string;
  value: number;
  href: string;
  accent?: boolean;
}>;

export function MetricsGrid({
  pendingReports,
  severeReports,
  pendingCorrections,
  duplicateRoutes,
  pendingClaims,
  hiddenContent,
}: Readonly<{
  pendingReports: number;
  severeReports: number;
  pendingCorrections: number;
  duplicateRoutes: number;
  pendingClaims: number;
  hiddenContent: number;
}>) {
  const metrics: Metric[] = [
    { label: copy.pendingReports, value: pendingReports, href: "/review?status=pending" },
    {
      label: copy.severeReports,
      value: severeReports,
      href: "/review?status=pending&severity=severe",
      accent: severeReports > 0,
    },
    { label: copy.pendingCorrections, value: pendingCorrections, href: "/review?status=pending&kind=route_correction" },
    { label: copy.duplicateRoutes, value: duplicateRoutes, href: "/review?status=pending&kind=merge_suggestion" },
    { label: copy.pendingClaims, value: pendingClaims, href: "/review?status=pending" },
    { label: copy.hiddenContent, value: hiddenContent, href: "/review?status=resolved" },
  ];

  return (
    <ul className="metrics-grid" aria-label={en.overview.title}>
      {metrics.map((metric) => (
        <li
          key={metric.label}
          className="metrics-grid__card"
          data-accent={metric.accent === true ? "true" : undefined}
        >
          <Link href={metric.href} aria-label={`${metric.label}: ${metric.value}. ${copy.viewQueue}`}>
            <span className="metrics-grid__value" aria-hidden="true">
              {metric.value}
            </span>
            <span className="metrics-grid__label">{metric.label}</span>
          </Link>
        </li>
      ))}
    </ul>
  );
}
