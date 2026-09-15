import { Skeleton } from "@/components/ui/skeleton";
import { en } from "@/lib/messages/en";

export default function PeopleLoading() {
  return (
    <section className="portal-page" aria-label={en.people.title}>
      <Skeleton className="review-filters__skeleton" />
      <Skeleton className="review-table__skeleton" />
    </section>
  );
}
