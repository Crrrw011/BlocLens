import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { getReviewItem, listReviewQueue } from "@/features/review/repository";
import { reviewKindSchema } from "@/features/review/schemas";
import type { ReviewKind, ReviewStatusFilter } from "@/features/review/types";
import { ReviewFilters } from "@/features/review/review-filters";
import { ReviewTable } from "@/features/review/review-table";

function single(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function parseStatus(value: unknown): ReviewStatusFilter {
  return value === "resolved" || value === "all" ? value : "pending";
}

function parseKind(value: unknown): ReviewKind | "all" {
  const parsed = reviewKindSchema.safeParse(value);
  return parsed.success ? parsed.data : "all";
}

function parseSeverity(value: unknown): "all" | "severe" | "normal" {
  return value === "severe" || value === "normal" ? value : "all";
}

function parseSelected(value: unknown): { kind: ReviewKind; id: string } | null {
  if (typeof value !== "string") return null;
  const separator = value.indexOf(":");
  if (separator <= 0) return null;
  const kind = reviewKindSchema.safeParse(value.slice(0, separator));
  const id = value.slice(separator + 1);
  if (!kind.success || !/^[0-9a-f-]{36}$/i.test(id)) return null;
  return { kind: kind.data, id };
}

export default async function ReviewPage({
  searchParams,
}: Readonly<{ searchParams?: Promise<Record<string, string | string[] | undefined>> }>) {
  const access = await requireStaff();
  const params = (await searchParams) ?? {};
  const query = {
    status: parseStatus(single(params.status)),
    kind: parseKind(single(params.kind)),
    severity: parseSeverity(single(params.severity)),
    q: (single(params.q) ?? "").slice(0, 200),
    cursor: single(params.cursor) ?? null,
    pageSize: 20,
  };
  const selected = parseSelected(single(params.selected));

  const queueResult = await listReviewQueue(query);
  if (!queueResult.ok) {
    throw new Error("Review queue is unavailable");
  }

  const itemResult = selected ? await getReviewItem(selected) : null;
  if (itemResult && !itemResult.ok && itemResult.error.code !== "not_found") {
    throw new Error("Review item is unavailable");
  }

  return (
    <section className="portal-page" aria-label={en.review.title}>
      <ReviewFilters current={query} />
      <ReviewTable
        items={queueResult.value.items}
        nextCursor={queueResult.value.nextCursor}
        selected={itemResult?.ok === true ? itemResult.value : selected ? "unavailable" : null}
        canSeeReporter={access.role === "admin"}
      />
    </section>
  );
}
