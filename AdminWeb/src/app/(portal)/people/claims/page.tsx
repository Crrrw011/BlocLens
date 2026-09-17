import { redirect } from "next/navigation";

function single(value: string | string[] | undefined): string | undefined {
  return Array.isArray(value) ? value[0] : value;
}

export default async function ClaimsPage({
  searchParams,
}: Readonly<{ searchParams?: Promise<Record<string, string | string[] | undefined>> }>) {
  const params = (await searchParams) ?? {};
  const selected = single(params.selected);
  redirect(
    selected && /^[0-9a-f-]{36}$/i.test(selected)
      ? `/people?tab=claims&selected=${selected}`
      : "/people?tab=claims",
  );
}
