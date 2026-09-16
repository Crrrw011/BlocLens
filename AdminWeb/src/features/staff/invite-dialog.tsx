"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { en } from "@/lib/messages/en";
import { revalidateStaff } from "./staff-actions";

const copy = en.people.staff;

type InviteResult =
  | { status: "idle" }
  | { status: "ok" }
  | { status: "error"; message: string };

export function InviteDialog({
  canInviteAdmin,
  onChanged,
}: Readonly<{ canInviteAdmin: boolean; onChanged: () => Promise<void> }>) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [result, setResult] = useState<InviteResult>({ status: "idle" });
  const [pending, setPending] = useState(false);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setPending(true);
    setResult({ status: "idle" });
    try {
      const form = new FormData(event.currentTarget);
      const response = await fetch("/api/staff/invitations", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          email: String(form.get("email") ?? ""),
          role: String(form.get("role") ?? ""),
          reason: String(form.get("reason") ?? ""),
        }),
      });
      const payload = (await response.json().catch(() => null)) as { status?: string } | null;
      if (response.ok && payload?.status === "accepted") {
        setResult({ status: "ok" });
        // Purge the roster fetch cache, reload state explicitly, then sync
        // the router cache. Closing first lifts modal inertness so the
        // refreshed roster is interactive right away.
        await revalidateStaff();
        await onChanged();
        router.refresh();
        setOpen(false);
      } else {
        setResult({ status: "error", message: copy.unavailable });
      }
    } catch {
      setResult({ status: "error", message: copy.unavailable });
    } finally {
      setPending(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <Button type="button" onClick={() => setOpen(true)}>
        {copy.invite}
      </Button>
      <DialogContent title={copy.invite}>
        <form onSubmit={submit}>
          <label htmlFor="invite-email">{copy.inviteEmailLabel}</label>
          <input id="invite-email" name="email" type="email" required maxLength={320} />
          <label htmlFor="invite-role">{copy.inviteRoleLabel}</label>
          <select id="invite-role" name="role" defaultValue="moderator">
            <option value="moderator">moderator</option>
            {canInviteAdmin ? <option value="admin">admin</option> : null}
          </select>
          <label htmlFor="invite-reason">{copy.inviteReasonLabel}</label>
          <textarea
            id="invite-reason"
            name="reason"
            required
            minLength={1}
            maxLength={2000}
          />
          <div aria-live="polite">
            {result.status === "ok" ? <p role="status">{copy.inviteAccepted}</p> : null}
            {result.status === "error" ? <p role="alert">{result.message}</p> : null}
          </div>
          <Button type="submit" disabled={pending} aria-busy={pending}>
            {copy.inviteSubmit}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}
