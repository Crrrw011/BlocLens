"use client";

import { useActionState, useEffect, useId, useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { en } from "@/lib/messages/en";
import { decideReview } from "./actions";
import type { ReviewDecision, ReviewKind } from "./types";

const copy = en.review.decisions;

export function ActionDialog({
  kind,
  id,
  title,
  decision,
  expectedUpdatedAt,
  open,
  onOpenChange,
}: Readonly<{
  kind: ReviewKind;
  id: string;
  title: string;
  decision: ReviewDecision;
  expectedUpdatedAt: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}>) {
  const router = useRouter();
  // One key per dialog opening: safe retries reuse it, a fresh opening mints a new one.
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const reasonId = useId();
  const [state, action, pending] = useActionState(decideReview, { status: "idle" });

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
      <DialogContent title={`${copy.title}: ${copy.actions[decision]}`}>
        <p>
          {title} · {copy.actions[decision]}
        </p>
      <form action={action}>
        <input type="hidden" name="kind" value={kind} />
        <input type="hidden" name="id" value={id} />
        <input type="hidden" name="decision" value={decision} />
        <input type="hidden" name="expectedUpdatedAt" value={expectedUpdatedAt} />
        <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
        <label htmlFor={reasonId}>{copy.reasonLabel}</label>
        <textarea
          id={reasonId}
          name="reason"
          required
          minLength={1}
          maxLength={2000}
          placeholder={copy.reasonPlaceholder}
          aria-describedby={conflicted ? "decision-conflict" : undefined}
        />
        <div id="decision-feedback" aria-live="polite">
          {state.status === "error" && !conflicted ? (
            <p role="alert">{state.message}</p>
          ) : null}
          {conflicted ? (
            <p id="decision-conflict" role="alert">
              {copy.conflictTitle}. {copy.conflictBody}
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
