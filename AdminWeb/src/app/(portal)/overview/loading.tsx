import { Skeleton } from "@/components/ui/skeleton";
import { en } from "@/lib/messages/en";

export default function OverviewLoading() {
  return (
    <section className="portal-page" aria-label={en.shell.overviewWorkspace}>
      <ul className="metrics-grid" aria-hidden="true">
        {Array.from({ length: 6 }, (_, index) => (
          <li key={index} className="metrics-grid__card">
            <Skeleton className="metrics-grid__skeleton" />
          </li>
        ))}
      </ul>
      <div className="overview-panels" aria-hidden="true">
        <Skeleton className="overview-panel__skeleton" />
        <Skeleton className="overview-panel__skeleton" />
      </div>
    </section>
  );
}
