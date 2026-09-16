"use client";

import { useActionState, useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { en } from "@/lib/messages/en";
import { decideClaim } from "./claim-actions";

const copy = en.people.claims;

export type ClaimDecision = "approved" | "rejected";

export function ClaimDialog({
  claimId,
  decision,
  expectedUpdatedAt,
  open,
  onOpenChange,
}: Readonly<{
  claimId: string;
  decision: ClaimDecision;
  expectedUpdatedAt: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}>) {
  const router = useRouter();
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [state, formAction, pending] = useActionState(decideClaim, { status: "idle" });

  useEffect(() => {
    if (open) setIdempotencyKey(crypto.randomUUID());
  }, [open ]);

  useEffect(() => {
    if (state.status === "success") {
      onOpenChange(false);
      router.refresh();
    }
  }, [state, onOpenChange, router]);

  const conflicted = state.status === "error" && "conflict" in state;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent title={decision === "approved" ? copy.approve : copy.reject}>
        <form action={formAction}>
          <input type="hidden" name="claimId" value={claimId} />
          <input type="hidden" name="decision" value={decision} />
          <input type="hidden" name="expectedUpdatedAt" value={expectedUpdatedAt} />
          <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
          <label htmlFor={`claim-note-${claimId}`}>{copy.noteLabel}</label>
          <textarea
            id={`claim-note-${claimId}`}
            name="reviewNote"
            required
            minLength={1}
            maxLength={1000}
            placeholder={copy.notePlaceholder}
          />
          <div aria-live="polite">
            {state.status === "error" ? (
              <p role="alert">
                {conflicted ? `${copy.conflictTitle}. ` : ""}
                {state.message}
              </p>
            ) : null}
          </div>
          <Button type="submit" disabled={pending} aria-busy={pending}>
            {copy.confirm}
          </Button>
          <Button type="button" onClick={() => onOpenChange(false)}>
            {copy.cancel}
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}
