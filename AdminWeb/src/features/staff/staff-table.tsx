"use client";

import { useActionState, useState } from "react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import { revokeInvitation, setStaffActive } from "./staff-actions";
import type { StaffInvitation, StaffMember } from "./repository";

const copy = en.people.staff;

function ReasonFields({ idPrefix }: Readonly<{ idPrefix: string }>) {
  return (
    <>
      <label htmlFor={`${idPrefix}-reason`}>{en.climbingData.lifecycle.reasonLabel}</label>
      <textarea
        id={`${idPrefix}-reason`}
        name="reason"
        required
        minLength={1}
        maxLength={2000}
      />
    </>
  );
}

export function StaffTables({
  staff,
  invitations,
  canManageAdministrators,
}: Readonly<{
  staff: StaffMember[];
  invitations: StaffInvitation[];
  canManageAdministrators: boolean;
}>) {
  const [revoking, setRevoking] = useState<string | null>(null);
  const [toggling, setToggling] = useState<{ id: string; active: boolean } | null>(null);

  return (
    <div>
      <section aria-labelledby="staff-roster">
        <h3 id="staff-roster">{copy.rosterTitle}</h3>
        <ul>
          {staff.map((member) => (
            <li key={`${member.user_id}:${member.role}`}>
              <strong>{member.username}</strong> · {member.role} ·{" "}
              {member.active ? copy.active : copy.inactive} ·{" "}
              {copy.columns.capability}:{" "}
              {member.can_manage_administrators ? "yes" : "no"}{" "}
              {(member.role === "moderator" ||
                (member.role === "admin" && canManageAdministrators)) && member.active ? (
                <Button
                  type="button"
                  onClick={() => setToggling({ id: member.user_id, active: false })}
                >
                  {copy.deactivate}
                </Button>
              ) : null}
              {!member.active ? (
                <Button
                  type="button"
                  onClick={() => setToggling({ id: member.user_id, active: true })}
                >
                  {copy.reactivate}
                </Button>
              ) : null}
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="staff-invitations">
        <h3 id="staff-invitations">{copy.invitationsTitle}</h3>
        <ul>
          {invitations.map((invitation) => (
            <li key={invitation.id}>
              <strong>{invitation.email}</strong> · {invitation.role} ·{" "}
              <StatusBadge tone={invitation.status === "pending" ? "warning" : "neutral"}>
                {copy.states[invitation.status]}
              </StatusBadge>{" "}· {copy.columns.expires}: {invitation.expires_at.slice(0, 10)}{" "}
              {invitation.status === "pending" ? (
                <Button type="button" onClick={() => setRevoking(invitation.id)}>
                  {copy.revoke}
                </Button>
              ) : null}
            </li>
          ))}
        </ul>
      </section>

      <AccessDialog
        key={revoking ?? toggling?.id ?? "closed"}
        revoking={revoking}
        toggling={toggling}
        onClose={() => {
          setRevoking(null);
          setToggling(null);
        }}
      />
    </div>
  );
}

function AccessDialog({
  revoking,
  toggling,
  onClose,
}: Readonly<{
  revoking: string | null;
  toggling: { id: string; active: boolean } | null;
  onClose: () => void;
}>) {
  const open = revoking !== null || toggling !== null;
  // One key per dialog opening: safe retries reuse it.
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const [revokeState, revokeAction, revokePending] = useActionState(revokeInvitation, {
    status: "idle",
  });
  const [accessState, accessAction, accessPending] = useActionState(setStaffActive, {
    status: "idle",
  });
  const state = revoking ? revokeState : accessState;

  return (
    <Dialog open={open} onOpenChange={(next) => { if (!next) onClose(); }}>
      <DialogContent title={revoking ? copy.revoke : toggling?.active ? copy.reactivate : copy.deactivate}>
        {revoking ? (
          <form action={revokeAction}>
            <input type="hidden" name="invitationId" value={revoking} />
            <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
            <ReasonFields idPrefix="revoke" />
            <div aria-live="polite">
              {revokeState.status === "error" ? <p role="alert">{revokeState.message}</p> : null}
            </div>
            <Button type="submit" disabled={revokePending} aria-busy={revokePending}>
              {copy.revoke}
            </Button>
          </form>
        ) : toggling ? (
          <form action={accessAction}>
            <input type="hidden" name="targetUserId" value={toggling.id} />
            <input type="hidden" name="makeActive" value={String(toggling.active)} />
            <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
            <ReasonFields idPrefix="access" />
            <div aria-live="polite">
              {accessState.status === "error" ? <p role="alert">{accessState.message}</p> : null}
            </div>
            <Button type="submit" disabled={accessPending} aria-busy={accessPending}>
              {toggling.active ? copy.reactivate : copy.deactivate}
            </Button>
          </form>
        ) : null}
      </DialogContent>
    </Dialog>
  );
}
