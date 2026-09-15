import { Skeleton } from "@/components/ui/skeleton";
import { en } from "@/lib/messages/en";

export default function ClimbingDataLoading() {
  return (
    <section className="portal-page" aria-label={en.climbingData.title}>
      <Skeleton className="review-filters__skeleton" />
      <Skeleton className="review-table__skeleton" />
    </section>
  );
}
