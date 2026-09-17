import Link from "next/link";
import { redirect } from "next/navigation";

import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { listClaims } from "@/features/claims/repository";
import { ClaimsTable } from "@/features/claims/claims-table";
import { PeopleTable } from "@/features/people/people-table";
import { listUsers } from "@/features/people/repository";
import { getStaffRoster } from "@/features/staff/repository";
import { StaffWorkspace } from "@/features/staff/staff-workspace";

function single(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

const TABS = ["members", "staff", "claims"] as const;
type Tab = (typeof TABS)[number];

export default async function PeoplePage({
  searchParams,
}: Readonly<{ searchParams?: Promise<Record<string, string | string[] | undefined>> }>) {
  const access = await requireStaff();
  const params = (await searchParams) ?? {};
  const rawTab = single(params.tab);
  const tab: Tab = rawTab === "staff" || rawTab === "claims" ? rawTab : "members";
  if ((tab === "staff" || tab === "claims") && access.role !== "admin") {
    redirect("/access-denied");
  }

  return (
    <section className="portal-page" aria-label={en.people.title}>
      <div className="row-head">
        <div>
          <h1>{en.people.title}</h1>
          <div className="sub">
            {en.shell.roles[access.role]} · {en.people.subtitle}
          </div>
        </div>
      </div>
      {access.role === "admin" ? (
        <div className="seg" role="tablist" aria-label={en.people.title}>
          <Link href="/people?tab=members" aria-current={tab === "members" ? "page" : undefined}>
            {en.people.tabs.members}
          </Link>
          <Link href="/people?tab=staff" aria-current={tab === "staff" ? "page" : undefined}>
            {en.people.tabs.staff}
          </Link>
          <Link href="/people?tab=claims" aria-current={tab === "claims" ? "page" : undefined}>
            {en.people.tabs.claims}
          </Link>
        </div>
      ) : null}
      {tab === "members" ? <MembersTab params={params} /> : null}
      {tab === "staff" ? <StaffTab canManageAdministrators={access.canManageAdministrators} /> : null}
      {tab === "claims" ? <ClaimsTab selectedId={single(params.selected)} /> : null}
    </section>
  );
}

async function MembersTab({
  params,
}: Readonly<{ params: Record<string, string | string[] | undefined> }>) {
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
    <>
      <form className="review-filters__search" method="get" action="/people" role="search">
        <input type="hidden" name="tab" value="members" />
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
    </>
  );
}

async function StaffTab({
  canManageAdministrators,
}: Readonly<{ canManageAdministrators: boolean }>) {
  const roster = await getStaffRoster();
  if (!roster.ok) {
    throw new Error("Staff roster is unavailable");
  }
  return (
    <StaffWorkspace
      initialStaff={roster.value.staff}
      initialInvitations={roster.value.invitations}
      canManageAdministrators={canManageAdministrators}
    />
  );
}

async function ClaimsTab({ selectedId }: Readonly<{ selectedId: string | undefined }>) {
  const claims = await listClaims();
  const selected =
    selectedId && /^[0-9a-f-]{36}$/i.test(selectedId)
      ? (claims.find((claim) => claim.id === selectedId) ?? "unavailable")
      : null;
  return <ClaimsTable claims={claims} selected={selected} />;
}
