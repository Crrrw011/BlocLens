import { notFound } from "next/navigation";

import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { getUserSummary } from "@/features/people/repository";
import { UserDetail } from "@/features/people/user-detail";

export default async function UserDetailPage({
  params,
}: Readonly<{ params: Promise<{ id: string }> }>) {
  const access = await requireStaff();
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) {
    notFound();
  }
  const result = await getUserSummary(id);
  if (!result.ok) {
    if (result.error.code === "not_found") notFound();
    throw new Error("User detail is unavailable");
  }

  return (
    <section className="portal-page" aria-label={result.value.username}>
      <UserDetail
        summary={result.value}
        canPenalise={access.role === "admin"}
        canDelete={
          access.role === "admin" &&
          access.userId !== id &&
          result.value.staffRole === null
        }
      />
    </section>
  );
}
