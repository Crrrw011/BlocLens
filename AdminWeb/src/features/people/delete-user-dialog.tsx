"use client";

import { useActionState, useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { en } from "@/lib/messages/en";
import { deleteUser } from "./delete-user-action";

const copy = en.people.deletion;

export function DeleteUserDialog({
  userId,
  username,
}: Readonly<{ userId: string; username: string }>) {
  const [open, setOpen] = useState(false);
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [state, formAction, pending] = useActionState(deleteUser, { status: "idle" });

  useEffect(() => {
    if (open) setIdempotencyKey(crypto.randomUUID());
  }, [open ]);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <Button type="button" onClick={() => setOpen(true)}>
        {copy.title}: {username}
      </Button>
      <DialogContent title={copy.warningTitle}>
        <p>{copy.warningBody}</p>
        <form action={formAction}>
          <input type="hidden" name="userId" value={userId} />
          <input type="hidden" name="username" value={username} />
          <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
          <label htmlFor="delete-user-confirm">{copy.usernameLabel}</label>
          <input
            id="delete-user-confirm"
            name="confirmedUsername"
            type="text"
            required
            minLength={1}
            maxLength={30}
            autoComplete="off"
          />
          <label htmlFor="delete-user-reason">{copy.reasonLabel}</label>
          <textarea
            id="delete-user-reason"
            name="reason"
            required
            minLength={1}
            maxLength={1000}
            placeholder={copy.reasonPlaceholder}
          />
          <div aria-live="polite">
            {state.status === "error" ? <p role="alert">{state.message}</p> : null}
          </div>
          <Button type="submit" disabled={pending} aria-busy={pending}>
            {copy.confirm}
          </Button>
          <Button type="button" onClick={() => setOpen(false)}>
            {copy.cancel}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}
