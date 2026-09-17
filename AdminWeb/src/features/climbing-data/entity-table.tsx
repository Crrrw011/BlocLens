"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";

import { DataTable } from "@/components/ui/data-table";
import { EmptyState } from "@/components/ui/empty-state";
import { en } from "@/lib/messages/en";
import { entityColumns } from "./columns";
import { EntityInspector } from "./entity-inspector";
import type { EntityDetail, EntityKind, EntityListItem } from "./types";

const copy = en.climbingData.table;

export function EntityTable({
  kind,
  items,
  nextCursor,
  selected,
  isAdmin,
}: Readonly<{
  kind: EntityKind;
  items: EntityListItem[];
  nextCursor: string | null;
  selected: EntityDetail | "unavailable" | null;
  isAdmin: boolean;
}>) {
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

  if (items.length === 0) {
    return (
      <EmptyState
        title={copy.emptyTitle}
        body={copy.emptyBody}
        action={<Link href={`/climbing-data/${kind}`}>{copy.nextPage}</Link>}
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
        columns={entityColumns[kind]}
        data={items}
        getRowId={(row) => row.id}
        selectedRowId={selected && selected !== "unavailable" ? selected.id : undefined}
        onRowActivate={(row) => select(row.id)}
        caption={en.climbingData.kinds[kind]}
      />
      {nextCursor ? (
        <Link
          href={`${pathname}?${new URLSearchParams({ ...Object.fromEntries(searchParams.entries()), cursor: nextCursor }).toString()}`}
        >
          {copy.nextPage}
        </Link>
      ) : null}
      <EntityInspector
        kind={kind}
        item={selected}
        isAdmin={isAdmin}
        triggerRef={{ current: trigger }}
        onClose={() => select(null)}
      />
    </div>
  );
}
