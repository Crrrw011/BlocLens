import { requireStaff } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { en } from "@/lib/messages/en";
import {
  MAX_EXPORT_DAYS,
  auditCsvHeader,
  auditRowToCsv,
  type AuditEvent,
} from "@/features/audit/export";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const copy = en.audit.export;
const headers = {
  "Cache-Control": "no-store",
  "Content-Type": "text/csv; charset=utf-8",
  "Content-Disposition": 'attachment; filename="bloclens-audit.csv"',
};

const PAGE_SIZE = 500;
const MAX_ROWS = 10000;

export async function GET(request: Request): Promise<Response> {
  let access;
  try {
    access = await requireStaff();
  } catch {
    return Response.json({ status: "denied" }, { status: 403 });
  }
  void access;

  const params = new URL(request.url).searchParams;
  const from = params.get("from");
  const to = params.get("to");
  const fromMs = from ? Date.parse(from) : Number.NaN;
  const toMs = to ? Date.parse(to) : Number.NaN;
  if (
    !from ||
    !to ||
    Number.isNaN(fromMs) ||
    Number.isNaN(toMs) ||
    fromMs >= toMs ||
    toMs - fromMs > MAX_EXPORT_DAYS * 86400000
  ) {
    return Response.json({ status: "invalid", message: copy.tooWide }, { status: 400 });
  }

  const supabase = await createServerClient();
  const filters = {
    actor_filter: params.get("actor"),
    action_filter: params.get("action"),
    target_filter: params.get("target"),
    outcome_filter: params.get("outcome"),
  };

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      controller.enqueue(encoder.encode(`\uFEFF${auditCsvHeader()}\n`));
      let cursor: string | null = null;
      let emitted = 0;
      try {
        for (;;) {
          const { data, error } = await supabase.rpc("admin_list_audit", {
            ...filters,
            range_start: from,
            range_end: to,
            page_after: cursor,
            page_size: PAGE_SIZE,
          });
          if (error || !Array.isArray(data) || data.length === 0) break;
          const rows = data as Array<Record<string, unknown>>;
          const page = rows.slice(0, PAGE_SIZE);
          for (const row of page) {
            if (emitted >= MAX_ROWS) break;
            const event = {
              id: String(row.id ?? ""),
              actorId: (row.actor_id as string | null) ?? null,
              actionKey: String(row.action_key ?? ""),
              targetType: String(row.target_type ?? ""),
              targetId: (row.target_id as string | null) ?? null,
              reason: String(row.reason ?? ""),
              outcome: String(row.outcome ?? ""),
              beforeSummary: (row.before_summary as Record<string, unknown>) ?? {},
              afterSummary: (row.after_summary as Record<string, unknown>) ?? {},
              createdAt: String(row.created_at ?? ""),
            } satisfies AuditEvent;
            controller.enqueue(encoder.encode(`${auditRowToCsv(event)}\n`));
            emitted += 1;
          }
          if (rows.length <= PAGE_SIZE || emitted >= MAX_ROWS) break;
          const last = page[page.length - 1]!;
          cursor = `${last.created_at}|${last.id}`;
        }
        controller.close();
      } catch {
        controller.error(new Error("export failed"));
      }
    },
  });

  return new Response(stream, { headers });
}
