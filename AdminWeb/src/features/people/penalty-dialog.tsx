"use client";

import { useActionState, useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { en } from "@/lib/messages/en";
import { applyPenalty, reversePenalty } from "./penalty-actions";
import type { PenaltyKind } from "./types";

const copy = en.people.penalties;

const KINDS: PenaltyKind[] = ["publishing_restriction", "timed_suspension", "permanent_ban"];

export function PenaltyDialog({
  userId,
  username,
}: Readonly<{ userId: string; username: string }>) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [kind, setKind] = useState<PenaltyKind>("publishing_restriction");
  const [endsLocal, setEndsLocal] = useState("");
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [state, formAction, pending] = useActionState(applyPenalty, { status: "idle" });

  useEffect(() => {
    if (open) setIdempotencyKey(crypto.randomUUID());
  }, [open ]);

  useEffect(() => {
    if (state.status === "success") {
      setOpen(false);
      router.refresh();
    }
  }, [state, router]);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <Button type="button" onClick={() => setOpen(true)}>
        {copy.title}: {username}
      </Button>
      <DialogContent title={copy.title}>
        <form action={formAction}>
          <input type="hidden" name="userId" value={userId} />
          <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
          <label htmlFor="penalty-kind">{copy.kindLabel}</label>
          <select
            id="penalty-kind"
            name="kind"
            value={kind}
            onChange={(event) => setKind(event.target.value as PenaltyKind)}
          >
            {KINDS.map((option) => (
              <option key={option} value={option}>
                {copy.kinds[option]}
              </option>
            ))}
          </select>
          {kind === "timed_suspension" ? (
            <>
              <label htmlFor="penalty-ends">{copy.endsLabel}</label>
              <input
                id="penalty-ends"
                type="datetime-local"
                value={endsLocal}
                onChange={(event) => setEndsLocal(event.target.value)}
                required
              />
              {/* Server actions require an offset timestamp; the local
                  picker value is converted to ISO on submit. */}
              <input
                type="hidden"
                name="endsAt"
                value={endsLocal === "" ? "" : new Date(endsLocal).toISOString()}
              />
            </>
          ) : null}
          <label htmlFor="penalty-reason">{copy.reasonLabel}</label>
          <textarea
            id="penalty-reason"
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

export function ReversePenaltyButton({ actionId }: Readonly<{ actionId: string }>) {
  const router = useRouter();
  const [idempotencyKey] = useState(() => crypto.randomUUID());
  const [state, formAction, pending] = useActionState(reversePenalty, { status: "idle" });

  useEffect(() => {
    if (state.status === "success") router.refresh();
  }, [state, router]);

  return (
    <form action={formAction} aria-label={`${copy.reverse}: ${actionId}`}>
      <input type="hidden" name="actionId" value={actionId} />
      <input type="hidden" name="reason" value="Reversed from the portal" />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      <Button type="submit" disabled={pending} aria-busy={pending}>
        {copy.reverse}
      </Button>
      {state.status === "error" ? (
        <p role="alert">{state.message}</p>
      ) : null}
    </form>
  );
}
