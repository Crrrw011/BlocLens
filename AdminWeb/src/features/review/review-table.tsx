"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";

import { DataTable, type DataTableColumn } from "@/components/ui/data-table";
import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import type { ReviewQueueItem } from "./types";
import { ReviewInspector, type InspectorItem } from "./review-inspector";

const copy = en.review.table;

function waitingSince(iso: string, now: number): string {
  const diffDays = Math.max(0, Math.floor((now - Date.parse(iso)) / 86400000));
  return diffDays === 0 ? "today" : `${diffDays}d`;
}

function selectionHref(
  pathname: string,
  params: URLSearchParams,
  item: ReviewQueueItem | null,
): string {
  const next = new URLSearchParams(params);
  if (item) {
    next.set("selected", `${item.kind}:${item.id}`);
  } else {
    next.delete("selected");
  }
  const query = next.toString();
  return query === "" ? pathname : `${pathname}?${query}`;
}

const ALL_COLUMNS = ["item", "kind", "status", "route", "waiting"] as const;
type ColumnId = (typeof ALL_COLUMNS)[number];

export function ReviewTable({
  items,
  nextCursor,
  selected,
  canSeeReporter,
}: Readonly<{
  items: ReviewQueueItem[];
  nextCursor: string | null;
  selected: InspectorItem | "unavailable" | null;
  canSeeReporter: boolean;
}>) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [hidden, setHidden] = useState<ReadonlySet<ColumnId>>(new Set());
  const [trigger, setTrigger] = useState<HTMLElement | null>(null);
  const now = Date.now();

  const toggle = (id: ColumnId) => {
    setHidden((previous) => {
      const next = new Set(previous);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const definitions: Record<ColumnId, DataTableColumn<ReviewQueueItem>> = {
    item: {
      id: "item",
      header: copy.columns.item,
      cell: ({ row }) => row.original.title,
    },
    kind: {
      id: "kind",
      header: copy.columns.kind,
      cell: ({ row }) => row.original.kind,
    },
    status: {
      id: "status",
      header: copy.columns.status,
      cell: ({ row }) => (
        <StatusBadge tone={row.original.status === "open" ? "warning" : "neutral"}>
          {row.original.status}
        </StatusBadge>
      ),
    },
    route: {
      id: "route",
      header: copy.columns.route,
      cell: ({ row }) => row.original.routeLabel ?? row.original.gymName ?? "—",
    },
    waiting: {
      id: "waiting",
      header: copy.columns.waiting,
      cell: ({ row }) => waitingSince(row.original.createdAt, now),
    },
  };
  const columns = ALL_COLUMNS.filter((id) => !hidden.has(id)).map((id) => definitions[id]);

  const closeInspector = () => {
    router.push(selectionHref(pathname, new URLSearchParams(searchParams.toString()), null), {
      scroll: false,
    });
  };

  if (items.length === 0) {
    return (
      <EmptyState
        title={copy.emptyTitle}
        body={copy.emptyBody}
        action={<Link href="/review?status=pending">{copy.nextPage}</Link>}
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
      <div className="review-table__columns" role="group" aria-label={copy.showColumns}>
        {ALL_COLUMNS.map((id) => (
          <button
            key={id}
            type="button"
            aria-pressed={!hidden.has(id)}
            onClick={() => toggle(id)}
          >
            {copy.hideColumn} {id}
          </button>
        ))}
      </div>
      <DataTable
        columns={columns}
        data={items}
        getRowId={(row) => `${row.kind}:${row.id}`}
        selectedRowId={
          selected && selected !== "unavailable"
            ? `${selected.kind}:${selected.id}`
            : undefined
        }
        onRowActivate={(row) => {
          router.push(
            selectionHref(pathname, new URLSearchParams(searchParams.toString()), row),
            { scroll: false },
          );
        }}
        caption={en.review.title}
      />
      {nextCursor ? (
        <Link
          href={`${pathname}?${new URLSearchParams({ ...Object.fromEntries(searchParams.entries()), cursor: nextCursor }).toString()}`}
        >
          {copy.nextPage}
        </Link>
      ) : null}
      <ReviewInspector
        item={selected}
        canSeeReporter={canSeeReporter}
        triggerRef={{ current: trigger }}
        onClose={closeInspector}
      />
    </div>
  );
}
