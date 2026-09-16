import Link from "next/link";
import { redirect } from "next/navigation";

import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { createServerClient } from "@/lib/supabase/server";
import { ClaimsTable } from "@/features/claims/claims-table";
import type { ClaimRow } from "@/features/claims/claim-inspector";

function single(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

export default async function ClaimsPage({
  searchParams,
}: Readonly<{ searchParams?: Promise<Record<string, string | string[] | undefined>> }>) {
  const access = await requireStaff();
  if (access.role !== "admin") {
    redirect("/access-denied");
  }
  const params = (await searchParams) ?? {};
  const selectedId = single(params.selected);

  const supabase = await createServerClient();
  const { data, error } = await supabase
    .from("gym_claims")
    .select("id,gym_id,applicant_id,domain_email,verification_method,status,review_note,created_at,updated_at")
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) {
    throw new Error("Gym claims are unavailable");
  }

  const gymIds = [...new Set((data ?? []).map((row) => row.gym_id))];
  const applicantIds = [...new Set((data ?? []).map((row) => row.applicant_id).filter(Boolean))];
  const [{ data: gyms }, { data: profiles }] = await Promise.all([
    supabase.from("gyms").select("id,name").in("id", gymIds.length > 0 ? gymIds : ["00000000-0000-0000-0000-000000000000"]),
    supabase.from("profiles").select("id,username").in("id", applicantIds.length > 0 ? applicantIds as string[] : ["00000000-0000-0000-0000-000000000000"]),
  ]);
  const gymNames = new Map((gyms ?? []).map((gym) => [gym.id, gym.name]));
  const usernames = new Map((profiles ?? []).map((profile) => [profile.id, profile.username]));

  const claims: ClaimRow[] = (data ?? []).map((row) => ({
    id: row.id,
    gymId: row.gym_id,
    gymName: gymNames.get(row.gym_id) ?? row.gym_id,
    applicantId: row.applicant_id,
    applicantName: row.applicant_id ? (usernames.get(row.applicant_id) ?? row.applicant_id) : "—",
    domainEmail: String(row.domain_email),
    verificationMethod: row.verification_method,
    status: row.status,
    reviewNote: row.review_note,
    updatedAt: row.updated_at,
    createdAt: row.created_at,
  }));

  const selected =
    selectedId && /^[0-9a-f-]{36}$/i.test(selectedId)
      ? (claims.find((claim) => claim.id === selectedId) ?? "unavailable")
      : null;

  return (
    <section className="portal-page" aria-label={en.people.claims.title}>
      <nav aria-label={en.people.title}>
        <Link href="/people">{en.people.title}</Link>
      </nav>
      <ClaimsTable claims={claims} selected={selected} />
    </section>
  );
}
