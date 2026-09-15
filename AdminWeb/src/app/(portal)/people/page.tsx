import Link from "next/link";

import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { PeopleTable } from "@/features/people/people-table";
import { listUsers } from "@/features/people/repository";

function single(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

export default async function PeoplePage({
  searchParams,
}: Readonly<{ searchParams?: Promise<Record<string, string | string[] | undefined>> }>) {
  const access = await requireStaff();
  const params = (await searchParams) ?? {};
  const query = {
    q: (single(params.q) ?? "").slice(0, 200),
    cursor: single(params.cursor) ?? null,
    pageSize: 20,
  };

  const result = await listUsers(query);
  if (!result.ok) {
    throw new Error("People list is unavailable");
  }

  return (
    <section className="portal-page" aria-label={en.people.title}>
      {access.role === "admin" ? (
        <nav aria-label={en.people.staffLink}>
          <Link href="/staff">{en.people.staffLink}</Link>
        </nav>
      ) : null}
      <form className="review-filters__search" method="get" action="/people" role="search">
        <label htmlFor="people-search">{en.people.searchLabel}</label>
        <input
          id="people-search"
          name="q"
          type="search"
          defaultValue={query.q}
          placeholder={en.people.searchPlaceholder}
          maxLength={200}
        />
        <button type="submit">{en.people.searchSubmit}</button>
      </form>
      <PeopleTable
        items={result.value.items}
        nextCursor={result.value.nextCursor}
        search={query.q}
      />
    </section>
  );
}
