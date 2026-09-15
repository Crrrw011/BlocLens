import Link from "next/link";
import { notFound } from "next/navigation";

import { StatusBadge } from "@/components/ui/status-badge";
import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { getEntityDetail } from "@/features/climbing-data/repository";
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

const RELATED_LINKS: Record<string, EntityKind> = {
  photos: "route_photo",
  beta_links: "beta_link",
  zones: "wall_zone",
  wall_zones: "wall_zone",
  routes: "route",
};

function formatValue(value: unknown): string {
  if (value === null || value === undefined) return "—";
  if (Array.isArray(value)) return value.length === 0 ? "—" : value.map(String).join(", ");
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
}

export default async function ClimbingDataDetailPage({
  params,
}: Readonly<{ params: Promise<{ kind: string; id: string }> }>) {
  await requireStaff();
  const { kind, id } = await params;
  if (!KINDS.includes(kind as EntityKind) || !/^[0-9a-f-]{36}$/i.test(id)) {
    notFound();
  }
  const entityKind = kind as EntityKind;
  const result = await getEntityDetail({ kind: entityKind, id });
  if (!result.ok) {
    if (result.error.code === "not_found") notFound();
    throw new Error("Entity detail is unavailable");
  }
  const item = result.value;
  const copy = en.climbingData;

  return (
    <section className="portal-page" aria-label={item.title}>
      <nav aria-label={copy.kinds[entityKind]}>
        <Link href={`/climbing-data/${entityKind}`}>{copy.kinds[entityKind]}</Link>
      </nav>
      <h2>
        {item.title} <StatusBadge tone="neutral">{item.status}</StatusBadge>
      </h2>
      {item.subtitle ? <p>{item.subtitle}</p> : null}

      <section aria-labelledby="entity-identifiers">
        <h3 id="entity-identifiers">{copy.detail.identifiers}</h3>
        <dl>
          <div className="inspector-detail">
            <dt>id</dt>
            <dd>{item.id}</dd>
          </div>
          {Object.entries(item.details)
            .filter(([, value]) => value !== null && value !== undefined && value !== "")
            .map(([key, value]) => (
              <div className="inspector-detail" key={key}>
                <dt>{key.replaceAll("_", " ")}</dt>
                <dd>{formatValue(value)}</dd>
              </div>
            ))}
        </dl>
      </section>

      <section aria-labelledby="entity-dependencies">
        <h3 id="entity-dependencies">{copy.inspector.dependents}</h3>
        {Object.entries(item.related).map(([key, value]) => {
          const target = RELATED_LINKS[key];
          const ids = Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];
          if (ids.length === 0 || !target) return null;
          return (
            <div key={key}>
              <h4>{key.replaceAll("_", " ")}</h4>
              <ul>
                {ids.slice(0, 50).map((relatedId) => (
                  <li key={relatedId}>
                    <Link href={`/climbing-data/${target}/${relatedId}`}>{relatedId}</Link>
                  </li>
                ))}
              </ul>
            </div>
          );
        })}
      </section>

      <section aria-labelledby="entity-history">
        <h3 id="entity-history">{copy.inspector.moderationHistory}</h3>
        {item.moderationHistory.length === 0 ? (
          <p>{copy.inspector.noHistory}</p>
        ) : (
          <ul>
            {item.moderationHistory.map((entry) => (
              <li key={entry.id}>
                {entry.actionType} · {entry.createdAt} · {entry.reason}
              </li>
            ))}
          </ul>
        )}
      </section>

      <p>
        {copy.detail.timestamps}: {item.createdAt} → {item.updatedAt}
      </p>
    </section>
  );
}
