"use client";

import { useActionState, useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { en } from "@/lib/messages/en";
import { setVisibility } from "./visibility-action";
import type { EntityKind } from "./types";

const copy = en.climbingData.visibility;

export type VisibilityAction = "archive" | "unarchive" | "hide" | "unhide";

export function VisibilityDialog({
  kind,
  id,
  action,
  expectedUpdatedAt,
  open,
  onOpenChange,
}: Readonly<{
  kind: Extract<EntityKind, "wall_zone" | "route_photo" | "beta_link" | "route_comment">;
  id: string;
  action: VisibilityAction;
  expectedUpdatedAt: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}>) {
  const router = useRouter();
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [reasonId] = useState(() => `visibility-reason-${crypto.randomUUID()}`);
  const [state, formAction, pending] = useActionState(setVisibility, { status: "idle" });

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
          <input type="hidden" name="kind" value={kind} />
          <input type="hidden" name="id" value={id} />
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
