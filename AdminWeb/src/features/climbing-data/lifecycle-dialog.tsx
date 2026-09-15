"use client";

import { useActionState, useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { en } from "@/lib/messages/en";
import { changeLifecycle } from "./actions";

const copy = en.climbingData.lifecycle;

export function LifecycleDialog({
  routeId,
  action,
  expectedUpdatedAt,
  open,
  onOpenChange,
}: Readonly<{
  routeId: string;
  action: "archive" | "unarchive" | "hide" | "unhide";
  expectedUpdatedAt: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}>) {
  const router = useRouter();
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [reasonId] = useState(() => `lifecycle-reason-${crypto.randomUUID()}`);
  const [state, formAction, pending] = useActionState(changeLifecycle, { status: "idle" });

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
      <DialogContent title={`${copy.title}: ${copy.actions[action]}`}>
        <form action={formAction}>
          <input type="hidden" name="routeId" value={routeId} />
          <input type="hidden" name="action" value={action} />
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
          />
          <div aria-live="polite">
            {state.status === "error" ? (
              <p role="alert">
                {conflicted ? `${copy.title}. ` : ""}
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
