import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { AuditFilters } from "@/features/audit/audit-filters";
import { AuditTable } from "@/features/audit/audit-table";
import { MAX_EXPORT_DAYS } from "@/features/audit/export";
import { listAuditEvents } from "@/features/audit/repository";

function single(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

function defaultRange(): { from: string; to: string } {
  const to = new Date();
  const from = new Date(to.getTime() - 30 * 86400000);
  return { from: from.toISOString(), to: to.toISOString() };
}

export default async function AuditPage({
  searchParams,
}: Readonly<{ searchParams?: Promise<Record<string, string | string[] | undefined>> }>) {
  await requireStaff();
  const params = (await searchParams) ?? {};
  const defaults = defaultRange();
  const filters = {
    actorId: single(params.actor) ?? null,
    action: single(params.action) ?? null,
    targetType: single(params.target) ?? null,
    outcome: single(params.outcome) ?? null,
    from: single(params.from) ?? defaults.from,
    to: single(params.to) ?? defaults.to,
    cursor: single(params.cursor) ?? null,
    pageSize: 20,
  };

  const result = await listAuditEvents(filters);
  if (!result.ok) {
    throw new Error("Audit events are unavailable");
  }

  const keepParams: Record<string, string> = {};
  for (const [key, param] of Object.entries({
    actor: filters.actorId,
    action: filters.action,
    target: filters.targetType,
    outcome: filters.outcome,
    from: filters.from,
    to: filters.to,
  })) {
    if (param) keepParams[key] = param;
  }
  const exportHref = `/api/audit/export?${new URLSearchParams(keepParams).toString()}`;

  return (
    <section className="portal-page" aria-label={en.audit.title}>
      <AuditFilters
        defaults={{
          actorId: filters.actorId ?? "",
          action: filters.action ?? "",
          targetType: filters.targetType ?? "",
          outcome: filters.outcome ?? "",
          from: filters.from,
          to: filters.to,
        }}
        exportHref={exportHref}
      />
      <p className="sr-only">Maximum export window: {MAX_EXPORT_DAYS} days.</p>
      <AuditTable
        items={result.value.items}
        nextCursor={result.value.nextCursor}
        keepParams={keepParams}
      />
    </section>
  );
}
