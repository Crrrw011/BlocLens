import { notFound } from "next/navigation";

import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { EntityFilters } from "@/features/climbing-data/entity-filters";
import { EntityTable } from "@/features/climbing-data/entity-table";
import { getEntityDetail, listEntities } from "@/features/climbing-data/repository";
import type { EntityKind } from "@/features/climbing-data/types";

const KINDS: EntityKind[] = [
  "gym",
  "wall_zone",
  "route",
  "reset",
  "route_photo",
  "beta_link",
  "route_comment",
];

function single(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

export default async function ClimbingDataKindPage({
  params,
  searchParams,
}: Readonly<{
  params: Promise<{ kind: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}>) {
  await requireStaff();
  const { kind } = await params;
  if (!KINDS.includes(kind as EntityKind)) {
    notFound();
  }
  const entityKind = kind as EntityKind;
  const query = (await searchParams) ?? {};
  const filters = {
    kind: entityKind,
    status: single(query.status) ?? "all",
    gym: single(query.gym) ?? "",
    q: (single(query.q) ?? "").slice(0, 200),
    cursor: single(query.cursor) ?? null,
    pageSize: 20,
  };
  const selectedId = single(query.selected);

  const [listResult, gymsResult] = await Promise.all([
    listEntities(filters),
    listEntities({ kind: "gym", status: "active", pageSize: 100 }),
  ]);
  if (!listResult.ok) {
    throw new Error("Entity list is unavailable");
  }
  const gyms = gymsResult.ok ? gymsResult.value.items : [];

  const itemResult =
    selectedId && /^[0-9a-f-]{36}$/i.test(selectedId)
      ? await getEntityDetail({ kind: entityKind, id: selectedId })
      : null;
  if (itemResult && !itemResult.ok && itemResult.error.code !== "not_found") {
    throw new Error("Entity detail is unavailable");
  }

  return (
    <section className="portal-page" aria-label={en.climbingData.kinds[entityKind]}>
      <EntityFilters current={filters} gyms={gyms} />
      <EntityTable
        kind={entityKind}
        items={listResult.value.items}
        nextCursor={listResult.value.nextCursor}
        selected={itemResult?.ok === true ? itemResult.value : selectedId ? "unavailable" : null}
      />
    </section>
  );
}
