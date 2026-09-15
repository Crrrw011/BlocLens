import Link from "next/link";

import { en } from "@/lib/messages/en";
import type { EntityKind, EntityListItem } from "./types";

const copy = en.climbingData.filters;
const kindCopy = en.climbingData.kinds;

const KINDS: EntityKind[] = [
  "gym",
  "wall_zone",
  "route",
  "reset",
  "route_photo",
  "beta_link",
  "route_comment",
];

const STATUSES: Record<EntityKind, string[]> = {
  gym: ["all", "active", "deleted"],
  wall_zone: ["all", "active", "archived"],
  route: ["all", "active", "hidden", "archived", "deleted"],
  reset: ["all", "pending", "confirmed", "estimated"],
  route_photo: ["all", "visible", "hidden", "deleted"],
  beta_link: ["all", "visible", "hidden", "deleted"],
  route_comment: ["all", "visible", "hidden", "deleted"],
};

export type EntityFilterState = Readonly<{
  kind: EntityKind;
  status: string;
  gym: string;
  q: string;
}>;

function href(kind: EntityKind, state: Omit<EntityFilterState, "kind">): string {
  const params = new URLSearchParams();
  if (state.status !== "all") params.set("status", state.status);
  if (state.gym !== "") params.set("gym", state.gym);
  if (state.q !== "") params.set("q", state.q);
  const query = params.toString();
  return query === "" ? `/climbing-data/${kind}` : `/climbing-data/${kind}?${query}`;
}

export function EntityFilters({
  current,
  gyms,
}: Readonly<{ current: EntityFilterState; gyms: EntityListItem[] }>) {
  const rest = { status: current.status, gym: current.gym, q: current.q };
  return (
    <div className="review-filters">
      <div className="review-filters__group" role="group" aria-label={copy.kindLabel}>
        {KINDS.map((kind) => (
          <Link
            key={kind}
            href={href(kind, { status: "all", gym: "", q: "" })}
            aria-current={kind === current.kind ? "page" : undefined}
          >
            {kindCopy[kind]}
          </Link>
        ))}
      </div>
      <div className="review-filters__group" role="group" aria-label={copy.statusLabel}>
        {STATUSES[current.kind].map((status) => (
          <Link
            key={status}
            href={href(current.kind, { ...rest, status })}
            aria-current={status === current.status ? "page" : undefined}
          >
            {status}
          </Link>
        ))}
      </div>
      <form className="review-filters__search" method="get" action={`/climbing-data/${current.kind}`} role="search">
        {current.status !== "all" ? <input type="hidden" name="status" value={current.status} /> : null}
        <label htmlFor="entity-gym">{copy.gymLabel}</label>
        <select id="entity-gym" name="gym" defaultValue={current.gym}>
          <option value="">{copy.allGyms}</option>
          {gyms.map((gym) => (
            <option key={gym.id} value={gym.id}>
              {gym.title}
            </option>
          ))}
        </select>
        <label htmlFor="entity-search">{copy.searchLabel}</label>
        <input
          id="entity-search"
          name="q"
          type="search"
          defaultValue={current.q}
          placeholder={copy.searchPlaceholder}
          maxLength={200}
        />
        <button type="submit">{copy.searchSubmit}</button>
      </form>
    </div>
  );
}
