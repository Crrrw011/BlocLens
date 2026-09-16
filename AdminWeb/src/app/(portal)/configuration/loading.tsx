import { Skeleton } from "@/components/ui/skeleton";
import { en } from "@/lib/messages/en";

export default function ConfigurationLoading() {
  return (
    <section className="portal-page" aria-label={en.configuration.title}>
      <Skeleton className="review-table__skeleton" />
    </section>
  );
}
