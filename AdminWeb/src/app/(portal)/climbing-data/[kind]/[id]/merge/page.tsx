import Link from "next/link";
import { notFound } from "next/navigation";

import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { listEntities } from "@/features/climbing-data/repository";
import { getMergeImpact } from "@/features/climbing-data/merge-action";
import { MergePreview } from "@/features/climbing-data/merge-preview";

const copy = en.climbingData.merge;

function single(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

const UUID_PATTERN = /^[0-9a-f-]{36}$/i;

export default async function RouteMergePage({
  params,
  searchParams,
}: Readonly<{
  params: Promise<{ kind: string; id: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}>) {
  const access = await requireStaff();
  const { kind, id } = await params;
  if (kind !== "route" || !UUID_PATTERN.test(id)) {
    notFound();
  }
  const query = (await searchParams) ?? {};
  const canonicalId = single(query.canonical);

  const candidatesResult = await listEntities({
    kind: "route",
    status: "active",
    pageSize: 50,
  });
  if (!candidatesResult.ok) {
    throw new Error("Merge candidates are unavailable");
  }
  const candidates = candidatesResult.value.items.filter((item) => item.id !== id);

  const impactResult =
    canonicalId && UUID_PATTERN.test(canonicalId) && canonicalId !== id
      ? await getMergeImpact(id, canonicalId)
      : null;
  if (impactResult && !impactResult.ok && impactResult.errorCode !== "not_found") {
    throw new Error(`Merge preview is unavailable: ${impactResult.errorCode}`);
  }

  return (
    <section className="portal-page" aria-label={copy.title}>
      <nav aria-label={copy.title}>
        <Link href={`/climbing-data/route/${id}`}>Back to route</Link>
      </nav>
      <h2>{copy.title}</h2>

      <form method="get" action={`/climbing-data/route/${id}/merge`}>
        <label htmlFor="merge-canonical">{copy.pickCanonical}</label>
        <select id="merge-canonical" name="canonical" defaultValue={canonicalId ?? ""}>
          <option value="">—</option>
          {candidates.map((candidate) => (
            <option key={candidate.id} value={candidate.id}>
              {candidate.title} · {candidate.subtitle ?? ""}
            </option>
          ))}
        </select>
        <button type="submit">{copy.preview}</button>
      </form>

      {impactResult?.ok === true ? (
        <MergePreview
          impact={impactResult.value}
          sourceId={id}
          canonicalId={canonicalId!}
          canExecute={access.role === "admin"}
        />
      ) : null}
      {impactResult && !impactResult.ok ? <p role="alert">{copy.unavailable}</p> : null}
    </section>
  );
}
