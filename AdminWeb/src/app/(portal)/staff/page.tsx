import { redirect } from "next/navigation";

import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { getStaffRoster } from "@/features/staff/repository";
import { StaffWorkspace } from "@/features/staff/staff-workspace";

export default async function StaffPage() {
  const access = await requireStaff();
  if (access.role !== "admin") {
    redirect("/access-denied");
  }

  const roster = await getStaffRoster();
  if (!roster.ok) {
    throw new Error("Staff roster is unavailable");
  }

  return (
    <section className="portal-page" aria-label={en.people.staff.title}>
      <h2>{en.people.staff.title}</h2>
      <StaffWorkspace
        initialStaff={roster.value.staff}
        initialInvitations={roster.value.invitations}
        canManageAdministrators={access.canManageAdministrators}
      />
    </section>
  );
}
