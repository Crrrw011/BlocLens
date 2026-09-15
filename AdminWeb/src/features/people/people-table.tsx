"use client";

import Link from "next/link";

import { DataTable, type DataTableColumn } from "@/components/ui/data-table";
import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import type { PersonRow } from "./types";

const copy = en.people.table;

const columns: DataTableColumn<PersonRow>[] = [
  {
    id: "user",
    header: copy.columns.user,
    cell: ({ row }) => <Link href={`/people/${row.original.userId}`}>{row.original.username}</Link>,
  },
  {
    id: "role",
    header: copy.columns.role,
    cell: ({ row }) => row.original.staffRole ?? "—",
  },
  {
    id: "restrictions",
    header: copy.columns.restrictions,
    cell: ({ row }) =>
      row.original.restrictionKinds.length === 0 ? (
        copy.noRestrictions
      ) : (
        <StatusBadge tone="warning">{row.original.restrictionKinds.join(", ")}</StatusBadge>
      ),
  },
  {
    id: "memberSince",
    header: copy.columns.memberSince,
    cell: ({ row }) => row.original.memberSince.slice(0, 10),
  },
];

export function PeopleTable({
  items,
  nextCursor,
  search,
}: Readonly<{ items: PersonRow[]; nextCursor: string | null; search: string }>) {
  if (items.length === 0) {
    return (
      <EmptyState
        title={copy.emptyTitle}
        body={copy.emptyBody}
        action={<Link href="/people">{copy.nextPage}</Link>}
      />
    );
  }

  return (
    <div className="review-table">
      <DataTable
        columns={columns}
        data={items}
        getRowId={(row) => row.userId}
        caption={en.people.title}
      />
      {nextCursor ? (
        <Link
          href={`/people?${new URLSearchParams(
            search === "" ? { cursor: nextCursor } : { q: search, cursor: nextCursor },
          ).toString()}`}
        >
          {copy.nextPage}
        </Link>
      ) : null}
    </div>
  );
}
