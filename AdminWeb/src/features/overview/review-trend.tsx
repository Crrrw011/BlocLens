import { en } from "@/lib/messages/en";
import type { TrendPoint } from "../review/types";

const copy = en.overview.trend;

function barHeight(value: number, max: number): number {
  if (max <= 0) return 0;
  return Math.max(value > 0 ? 4 : 0, Math.round((value / max) * 96));
}

export function ReviewTrend({ points }: Readonly<{ points: TrendPoint[] }>) {
  const max = points.reduce((top, point) => Math.max(top, point.opened, point.resolved), 0);
  const openedTotal = points.reduce((sum, point) => sum + point.opened, 0);
  const resolvedTotal = points.reduce((sum, point) => sum + point.resolved, 0);

  return (
    <section className="overview-panel" aria-labelledby="review-trend-title">
      <h2 id="review-trend-title">{copy.title}</h2>
      <p className="overview-panel__totals">
        {copy.opened}: {openedTotal} {copy.total} · {copy.resolved}: {resolvedTotal} {copy.total}
      </p>
      <div
        className="trend-chart"
        role="img"
        aria-label={`${copy.title}. ${copy.opened} ${openedTotal}, ${copy.resolved} ${resolvedTotal}.`}
      >
        <svg viewBox={`0 0 ${Math.max(points.length * 28, 28)} 112`} preserveAspectRatio="xMinYMax meet" aria-hidden="true">
          {points.map((point, index) => {
            const opened = barHeight(point.opened, max);
            const resolved = barHeight(point.resolved, max);
            return (
              <g key={point.day} transform={`translate(${index * 28}, 0)`}>
                <rect x={4} y={104 - opened} width={8} height={opened} rx={2} className="trend-chart__opened" />
                <rect x={14} y={104 - resolved} width={8} height={resolved} rx={2} className="trend-chart__resolved" />
              </g>
            );
          })}
        </svg>
      </div>
      <table className="sr-only">
        <caption>{copy.title}</caption>
        <tbody>
          {points.map((point) => (
            <tr key={point.day}>
              <th scope="row">{point.day}</th>
              <td>{`${copy.opened}: ${point.opened}`}</td>
              <td>{`${copy.resolved}: ${point.resolved}`}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}
