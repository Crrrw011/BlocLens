export type AuditOutcome = "succeeded" | "rejected" | "partially_failed" | "failed";

export type AuditFilter = {
  actorId?: string;
  action?: string;
  targetType?: string;
  outcome?: AuditOutcome;
  from: string;
  to: string;
  cursor?: string;
};

export type AuditEvent = {
  id: string;
  actorId: string | null;
  actionKey: string;
  targetType: string;
  targetId: string | null;
  reason: string;
  outcome: string;
  beforeSummary: Record<string, unknown>;
  afterSummary: Record<string, unknown>;
  createdAt: string;
};

export type AuditPage = {
  items: AuditEvent[];
  nextCursor: string | null;
};

export const EXPORT_COLUMNS = [
  "created_at",
  "actor_id",
  "action_key",
  "target_type",
  "target_id",
  "reason",
  "outcome",
  "before_summary",
  "after_summary",
] as const;

/** Spreadsheet-formula neutralisation: prefix =, +, -, @, tab, newline. */
export function escapeCsvCell(value: string): string {
  const needsPrefix = /^[=+\-@\t\n]/.test(value);
  const text = needsPrefix ? `'${value}` : value;
  if (/[",\n]/.test(text)) {
    return `"${text.replaceAll('"', '""')}"`;
  }
  return text;
}

export function auditRowToCsv(event: AuditEvent): string {
  const cells: Record<(typeof EXPORT_COLUMNS)[number], string> = {
    created_at: event.createdAt,
    actor_id: event.actorId ?? "",
    action_key: event.actionKey,
    target_type: event.targetType,
    target_id: event.targetId ?? "",
    reason: event.reason,
    outcome: event.outcome,
    before_summary: JSON.stringify(event.beforeSummary),
    after_summary: JSON.stringify(event.afterSummary),
  };
  return EXPORT_COLUMNS.map((column) => escapeCsvCell(cells[column])).join(",");
}

export function auditCsvHeader(): string {
  return EXPORT_COLUMNS.join(",");
}

/** Maximum export window in days. Raw IPs are never columns, so retention
    windows cannot leak through exports regardless of range. */
export const MAX_EXPORT_DAYS = 90;
