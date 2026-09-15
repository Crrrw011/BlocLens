import { en } from "@/lib/messages/en";
import type { DistributionSlice } from "../review/types";

export function QueueDistribution({ slices }: Readonly<{ slices: DistributionSlice[] }>) {
  const max = slices.reduce((top, slice) => Math.max(top, slice.count), 0);

  return (
    <section className="overview-panel" aria-labelledby="queue-distribution-title">
      <h2 id="queue-distribution-title">{en.overview.distribution.title}</h2>
      <ul className="distribution-list">
        {slices.map((slice) => (
          <li key={`${slice.kind}:${slice.status}`}>
            <span className="distribution-list__label">
              {slice.kind} · {slice.status}
            </span>
            <span
              className="distribution-list__bar"
              role="img"
              aria-label={`${slice.kind} ${slice.status}: ${slice.count}`}
            >
              <span
                aria-hidden="true"
                style={{ width: max > 0 ? `${Math.round((slice.count / max) * 100)}%` : "0%" }}
              />
            </span>
            <span className="distribution-list__count">{slice.count}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}
