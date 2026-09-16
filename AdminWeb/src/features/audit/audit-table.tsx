"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";

import { DataTable, type DataTableColumn } from "@/components/ui/data-table";
import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import { AuditInspector } from "./audit-inspector";
import type { AuditEvent } from "./export";

const copy = en.audit.table;

function tone(outcome: string): "success" | "warning" | "danger" | "neutral" {
  if (outcome === "succeeded") return "success";
  if (outcome === "failed") return "danger";
  return "warning";
}

const columns: DataTableColumn<AuditEvent>[] = [
  {
    id: "time",
    header: copy.columns.time,
    cell: ({ row }) => row.original.createdAt.slice(0, 19).replace("T", " "),
  },
  {
    id: "actor",
    header: copy.columns.actor,
    cell: ({ row }) => (row.original.actorId ? row.original.actorId.slice(0, 8) : "—"),
  },
  {
    id: "action",
    header: copy.columns.action,
    cell: ({ row }) => row.original.actionKey,
  },
  {
    id: "target",
    header: copy.columns.target,
    cell: ({ row }) => row.original.targetType,
  },
  {
    id: "outcome",
    header: copy.columns.outcome,
    cell: ({ row }) => <StatusBadge tone={tone(row.original.outcome)}>{row.original.outcome}</StatusBadge>,
  },
];

export function AuditTable({
  items,
  nextCursor,
  keepParams,
}: Readonly<{
  items: AuditEvent[];
  nextCursor: string | null;
  keepParams: Record<string, string>;
}>) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [trigger, setTrigger] = useState<HTMLElement | null>(null);
  const selectedId = searchParams.get("selected");
  const selected = items.find((item) => item.id === selectedId) ?? null;

  const select = (id: string | null) => {
    const next = new URLSearchParams(searchParams.toString());
    if (id) {
      next.set("selected", id);
    } else {
      next.delete("selected");
    }
    const query = next.toString();
    router.push(query === "" ? pathname : `${pathname}?${query}`, { scroll: false });
  };

  if (items.length === 0) {
    return (
      <EmptyState
        title={copy.emptyTitle}
        body={copy.emptyBody}
        action={<Link href="/audit">{copy.nextPage}</Link>}
      />
    );
  }

  return (
    <div
      className="review-table"
      onClickCapture={(event) => {
        const row = (event.target as HTMLElement).closest<HTMLElement>("tr[data-row-id]");
        if (row) setTrigger(row);
      }}
    >
      <DataTable
        columns={columns}
        data={items}
        getRowId={(row) => row.id}
        selectedRowId={selected?.id}
        onRowActivate={(row) => select(row.id)}
        caption={en.audit.title}
      />
      {nextCursor ? (
        <Link
          href={`${pathname}?${new URLSearchParams({ ...keepParams, cursor: nextCursor }).toString()}`}
        >
          {copy.nextPage}
        </Link>
      ) : null}
      <AuditInspector
        event={selected}
        triggerRef={{ current: trigger }}
        onClose={() => select(null)}
      />
    </div>
  );
}
