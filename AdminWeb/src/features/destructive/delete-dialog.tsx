"use client";

import { useActionState, useState } from "react";

import { Button } from "@/components/ui/button";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { en } from "@/lib/messages/en";
import type { DeletionImpact } from "../climbing-data/types";
import { permanentDelete } from "./delete-action";

const copy = en.climbingData.deletion;

export function DeleteDialog({
  targetType,
  targetId,
  title,
  impact,
  expectedUpdatedAt,
}: Readonly<{
  targetType: "route" | "route_photo" | "beta_link" | "route_comment";
  targetId: string;
  title: string;
  impact: DeletionImpact;
  expectedUpdatedAt: string;
}>) {
  const [open, setOpen] = useState(false);
  const [step, setStep] = useState<"warning" | "confirm">("warning");
  const [confirmation, setConfirmation] = useState("");
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [state, formAction, pending] = useActionState(permanentDelete, { status: "idle" });

  const reopen = (next: boolean) => {
    if (next) {
      // A fresh opening mints a fresh idempotency key; retries reuse it.
      setIdempotencyKey(crypto.randomUUID());
      setStep("warning");
      setConfirmation("");
    }
    setOpen(next);
  };

  const back = () => {
    // Back navigation resets the typed phrase so DELETE cannot carry over.
    setConfirmation("");
    setStep("warning");
  };

  const dependents = Object.entries(impact.dependentCounts).filter(([, count]) => count > 0);
  const conflicted = state.status === "error" && "conflict" in state;

  return (
    <Dialog open={open} onOpenChange={reopen}>
      <Button type="button" onClick={() => reopen(true)}>
        {copy.trigger}
      </Button>
      <DialogContent title={step === "warning" ? copy.warningTitle : copy.confirmTitle}>
        {step === "warning" ? (
          <div>
            <p>
              {title}. {copy.warningBody}
            </p>
            <section aria-label={copy.dependenciesTitle}>
              <h3>{copy.dependenciesTitle}</h3>
              {dependents.length === 0 && impact.storagePaths.length === 0 ? (
                <p>{copy.noDependencies}</p>
              ) : (
                <ul>
                  {dependents.map(([table, count]) => (
                    <li key={table}>
                      {table}: {count}
                    </li>
                  ))}
                  {impact.storagePaths.map((path) => (
                    <li key={path}>file: {path}</li>
                  ))}
                </ul>
              )}
            </section>
            {impact.alternative ? (
              <p>
                {copy.alternativeLabel}: {copy.alternatives[impact.alternative]}
              </p>
            ) : null}
            {impact.eligible ? (
              <Button type="button" onClick={() => setStep("confirm")}>
                {copy.continue}
              </Button>
            ) : (
              <p role="alert">
                {copy.blocked} ({impact.blockers.join(", ")})
              </p>
            )}
          </div>
        ) : (
          <form action={formAction} aria-label={copy.confirmTitle}>
            <p>{copy.confirmBody}</p>
            <input type="hidden" name="targetType" value={targetType} />
            <input type="hidden" name="targetId" value={targetId} />
            <input type="hidden" name="expectedUpdatedAt" value={expectedUpdatedAt} />
            <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
            <label htmlFor="delete-reason">{copy.reasonLabel}</label>
            <textarea
              id="delete-reason"
              name="reason"
              required
              minLength={1}
              maxLength={2000}
              placeholder={copy.reasonPlaceholder}
            />
            <label htmlFor="delete-confirmation">{copy.confirmationLabel}</label>
            <input
              id="delete-confirmation"
              name="confirmation"
              type="text"
              value={confirmation}
              onChange={(event) => setConfirmation(event.target.value)}
              autoComplete="off"
              required
            />
            <div aria-live="polite">
              {state.status === "error" ? (
                <p role="alert">
                  {conflicted ? `${copy.conflictTitle}. ` : ""}
                  {state.message}
                </p>
              ) : null}
            </div>
            <Button
              type="submit"
              disabled={pending || confirmation !== "DELETE"}
              aria-busy={pending}
            >
              {copy.confirm}
            </Button>
            <Button type="button" onClick={back}>
              {copy.back}
            </Button>
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
}
