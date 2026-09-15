import Link from "next/link";

import { en } from "@/lib/messages/en";
import type { ReviewKind, ReviewStatusFilter } from "./types";

const copy = en.review.filters;

export type ReviewFilterState = Readonly<{
  status: ReviewStatusFilter;
  kind: ReviewKind | "all";
  severity: "all" | "severe" | "normal";
  q: string;
}>;

function href(state: ReviewFilterState): string {
  const params = new URLSearchParams({ status: state.status });
  if (state.kind !== "all") params.set("kind", state.kind);
  if (state.severity !== "all") params.set("severity", state.severity);
  if (state.q !== "") params.set("q", state.q);
  return `/review?${params.toString()}`;
}

const STATUSES: ReviewStatusFilter[] = ["pending", "resolved", "all"];
const KINDS: Array<ReviewKind | "all"> = [
  "all",
  "content_report",
  "route_correction",
  "removal_report",
  "merge_suggestion",
];
const SEVERITIES: Array<"all" | "severe" | "normal"> = ["all", "severe", "normal"];

export function ReviewFilters({ current }: Readonly<{ current: ReviewFilterState }>) {
  return (
    <div className="review-filters">
      <div className="review-filters__group" role="group" aria-label={copy.statusLabel}>
        {STATUSES.map((status) => (
          <Link
            key={status}
            href={href({ ...current, status })}
            aria-current={status === current.status ? "page" : undefined}
          >
            {copy.statuses[status]}
          </Link>
        ))}
      </div>
      <div className="review-filters__group" role="group" aria-label={copy.kindLabel}>
        {KINDS.map((kind) => (
          <Link
            key={kind}
            href={href({ ...current, kind })}
            aria-current={kind === current.kind ? "page" : undefined}
          >
            {copy.kinds[kind]}
          </Link>
        ))}
      </div>
      <div className="review-filters__group" role="group" aria-label={copy.severityLabel}>
        {SEVERITIES.map((severity) => (
          <Link
            key={severity}
            href={href({ ...current, severity })}
            aria-current={severity === current.severity ? "page" : undefined}
          >
            {copy.severities[severity]}
          </Link>
        ))}
      </div>
      <form className="review-filters__search" method="get" action="/review" role="search">
        <input type="hidden" name="status" value={current.status} />
        {current.kind !== "all" ? <input type="hidden" name="kind" value={current.kind} /> : null}
        {current.severity !== "all" ? (
          <input type="hidden" name="severity" value={current.severity} />
        ) : null}
        <label htmlFor="review-search">{copy.searchLabel}</label>
        <input
          id="review-search"
          name="q"
          type="search"
          defaultValue={current.q}
          placeholder={copy.searchPlaceholder}
          maxLength={200}
        />
        <button type="submit">{copy.searchSubmit}</button>
      </form>
    </div>
  );
}
