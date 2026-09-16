import { Skeleton } from "@/components/ui/skeleton";
import { en } from "@/lib/messages/en";

export default function AuditLoading() {
  return (
    <section className="portal-page" aria-label={en.audit.title}>
      <Skeleton className="review-filters__skeleton" />
      <Skeleton className="review-table__skeleton" />
    </section>
  );
}
