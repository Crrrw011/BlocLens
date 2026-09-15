import Link from "next/link";
import { notFound } from "next/navigation";

import { StatusBadge } from "@/components/ui/status-badge";
import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { RouteActions } from "@/features/climbing-data/route-actions";
import { RouteEditForm } from "@/features/climbing-data/route-edit-form";
import { getEntityDetail } from "@/features/climbing-data/repository";
import type { EntityKind } from "@/features/climbing-data/types";
import { DeleteDialog } from "@/features/destructive/delete-dialog";
import { getDeletionImpact } from "@/features/destructive/deletion-impact";

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
  comments: "route_comment",
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
  const access = await requireStaff();
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
  const isAdmin = access.role === "admin";
  const deletable =
    entityKind === "route" ||
    entityKind === "route_photo" ||
    entityKind === "beta_link" ||
    entityKind === "route_comment";
  const impact =
    isAdmin && deletable ? await getDeletionImpact(entityKind, id) : null;

  return (
    <section className="portal-page" aria-label={item.title}>
      <nav aria-label={copy.kinds[entityKind]}>
        <Link href={`/climbing-data/${entityKind}`}>{copy.kinds[entityKind]}</Link>
        {entityKind === "route" && access.role === "admin" ? (
          <>
            {" · "}
            <Link href={`/climbing-data/route/${item.id}/merge`}>{copy.merge.title}</Link>
          </>
        ) : null}
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

      {isAdmin && deletable && impact ? (
        <section aria-labelledby="entity-delete">
          <h3 id="entity-delete">{copy.deletion.trigger}</h3>
          <DeleteDialog
            targetType={entityKind as "route" | "route_photo" | "beta_link" | "route_comment"}
            targetId={item.id}
            title={item.title}
            impact={impact}
            expectedUpdatedAt={item.updatedAt}
          />
        </section>
      ) : null}

      {entityKind === "route" ? (
        <>
          <section aria-labelledby="entity-edit">
            <h3 id="entity-edit">{copy.edit.title}</h3>
            <RouteEditForm
              id={item.id}
              colour={typeof item.details.colour === "string" ? item.details.colour : null}
              gymGrade={typeof item.details.gym_grade === "number" ? item.details.gym_grade : null}
              terrain={typeof item.details.terrain === "string" ? item.details.terrain : null}
              subjectiveGrade={
                typeof item.details.subjective_grade === "number"
                  ? item.details.subjective_grade
                  : null
              }
              expectedUpdatedAt={item.updatedAt}
            />
          </section>
          <section aria-labelledby="entity-lifecycle">
            <h3 id="entity-lifecycle">{copy.detail.lifecycle}</h3>
            <RouteActions
              routeId={item.id}
              lifecycle={typeof item.details.lifecycle === "string" ? item.details.lifecycle : ""}
              moderation={
                typeof item.details.moderation_status === "string"
                  ? item.details.moderation_status
                  : ""
              }
              expectedUpdatedAt={item.updatedAt}
              isAdmin={access.role === "admin"}
            />
          </section>
        </>
      ) : null}
    </section>
  );
}
