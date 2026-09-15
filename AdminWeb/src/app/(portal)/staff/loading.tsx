import { Skeleton } from "@/components/ui/skeleton";
import { en } from "@/lib/messages/en";

export default function StaffLoading() {
  return (
    <section className="portal-page" aria-label={en.people.staff.title}>
      <Skeleton className="review-table__skeleton" />
    </section>
  );
}
