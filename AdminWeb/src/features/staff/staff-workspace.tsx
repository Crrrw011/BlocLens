"use client";

import { useState } from "react";

import { InviteDialog } from "./invite-dialog";
import { refreshStaffRoster } from "./staff-actions";
import { StaffTables } from "./staff-table";
import type { StaffInvitation, StaffMember } from "./repository";

export function StaffWorkspace({
  initialStaff,
  initialInvitations,
  canManageAdministrators,
}: Readonly<{
  initialStaff: StaffMember[];
  initialInvitations: StaffInvitation[];
  canManageAdministrators: boolean;
}>) {
  const [staff, setStaff] = useState(initialStaff);
  const [invitations, setInvitations] = useState(initialInvitations);

  async function reload() {
    const roster = await refreshStaffRoster();
    if (roster) {
      setStaff(roster.staff);
      setInvitations(roster.invitations);
    }
  }

  return (
    <div>
      <InviteDialog canInviteAdmin={canManageAdministrators} onChanged={reload} />
      <StaffTables
        staff={staff}
        invitations={invitations}
        canManageAdministrators={canManageAdministrators}
        onChanged={reload}
      />
    </div>
  );
}
