"use client";

import Link from "next/link";

import { DataTable, type DataTableColumn } from "@/components/ui/data-table";
import { en } from "@/lib/messages/en";
import type { ReviewQueueItem } from "../review/types";

const copy = en.overview.priority;

function waitingSince(iso: string, now: number): string {
  const diffDays = Math.max(0, Math.floor((now - Date.parse(iso)) / 86400000));
  return diffDays === 0 ? "today" : `${diffDays}d`;
}

export function PriorityTable({ items }: Readonly<{ items: ReviewQueueItem[] }>) {
  const now = Date.now();
  const columns: DataTableColumn<ReviewQueueItem>[] = [
    {
      id: "item",
      header: copy.columns.item,
      cell: ({ row }) => (
        <Link href={`/review?status=pending&selected=${row.original.kind}:${row.original.id}`}>
          {row.original.title}
        </Link>
      ),
    },
    {
      id: "detail",
      header: copy.columns.detail,
      cell: ({ row }) =>
        row.original.routeLabel ?? row.original.gymName ?? row.original.targetType,
    },
    {
      id: "waiting",
      header: copy.columns.waiting,
      cell: ({ row }) => waitingSince(row.original.createdAt, now),
    },
  ];

  return (
    <section className="overview-panel" aria-labelledby="priority-table-title">
      <h2 id="priority-table-title">{copy.title}</h2>
      <p className="overview-panel__body">{copy.body}</p>
      <DataTable
        columns={columns}
        data={items}
        getRowId={(row) => `${row.kind}:${row.id}`}
        caption={copy.title}
      />
    </section>
  );
}
