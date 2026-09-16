"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";

import { DataTable, type DataTableColumn } from "@/components/ui/data-table";
import { EmptyState } from "@/components/ui/empty-state";
import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import { ClaimInspector, type ClaimRow } from "./claim-inspector";

const copy = en.people.claims;

const columns: DataTableColumn<ClaimRow>[] = [
  {
    id: "gym",
    header: copy.columns.gym,
    cell: ({ row }) => row.original.gymName,
  },
  {
    id: "applicant",
    header: copy.columns.applicant,
    cell: ({ row }) => row.original.applicantName,
  },
  {
    id: "method",
    header: copy.columns.method,
    cell: ({ row }) =>
      copy.methods[row.original.verificationMethod as keyof typeof copy.methods] ??
      row.original.verificationMethod,
  },
  {
    id: "status",
    header: copy.columns.status,
    cell: ({ row }) => (
      <StatusBadge tone={row.original.status === "submitted" ? "warning" : "neutral"}>
        {row.original.status}
      </StatusBadge>
    ),
  },
  {
    id: "created",
    header: copy.columns.created,
    cell: ({ row }) => row.original.createdAt.slice(0, 10),
  },
];

export function ClaimsTable({
  claims,
  selected,
}: Readonly<{ claims: ClaimRow[]; selected: ClaimRow | "unavailable" | null }>) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [trigger, setTrigger] = useState<HTMLElement | null>(null);

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

  if (claims.length === 0) {
    return (
      <EmptyState
        title={copy.emptyTitle}
        body={copy.emptyBody}
        action={<Link href="/overview">{en.overview.title}</Link>}
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
        data={claims}
        getRowId={(row) => row.id}
        selectedRowId={selected && selected !== "unavailable" ? selected.id : undefined}
        onRowActivate={(row) => select(row.id)}
        caption={copy.title}
      />
      <ClaimInspector
        claim={selected}
        triggerRef={{ current: trigger }}
        onClose={() => select(null)}
      />
    </div>
  );
}
