"use client";

import { useActionState, useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { en } from "@/lib/messages/en";
import { mergeRoutes } from "./merge-action";
import type { MergeImpact } from "./types";

const copy = en.climbingData.merge;

export function MergePreview({
  impact,
  sourceId,
  canonicalId,
  canExecute,
}: Readonly<{
  impact: MergeImpact;
  sourceId: string;
  canonicalId: string;
  canExecute: boolean;
}>) {
  const [acknowledged, setAcknowledged] = useState<ReadonlySet<string>>(new Set());
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [state, formAction, pending] = useActionState(mergeRoutes, { status: "idle" });

  useEffect(() => {
    if (state.status === "success") setIdempotencyKey(crypto.randomUUID());
  }, [state]);

  const toggle = (key: string) => {
    setAcknowledged((previous) => {
      const next = new Set(previous);
      if (next.has(key)) {
        next.delete(key);
      } else {
        next.add(key);
      }
      return next;
    });
  };

  const allAcknowledged = impact.conflicts.every((conflict) => acknowledged.has(conflict.key));
  const conflicted = state.status === "error" && "conflict" in state;

  return (
    <div className="merge-preview">
      <section aria-labelledby="merge-compare">
        <h3 id="merge-compare">{copy.compareTitle}</h3>
        <dl>
          <div className="inspector-detail">
            <dt>{copy.sourceLabel}</dt>
            <dd>
              {impact.source.colour ?? "—"} · {impact.source.id}
            </dd>
          </div>
          <div className="inspector-detail">
            <dt>{copy.canonicalLabel}</dt>
            <dd>
              {impact.canonical.colour ?? "—"} · {impact.canonical.id}
            </dd>
          </div>
        </dl>
      </section>

      <section aria-labelledby="merge-counts">
        <h3 id="merge-counts">{copy.countsTitle}</h3>
        <ul>
          {Object.entries(impact.counts).map(([table, count]) => (
            <li key={table}>
              {table}: {count}
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="merge-conflicts">
        <h3 id="merge-conflicts">{copy.conflictsTitle}</h3>
        {impact.conflicts.length === 0 ? (
          <p>{copy.noConflicts}</p>
        ) : (
          <>
            <p>{copy.conflictsBody}</p>
            <ul>
              {impact.conflicts.map((conflict) => (
                <li key={conflict.key}>
                  <label>
                    <input
                      type="checkbox"
                      checked={acknowledged.has(conflict.key)}
                      onChange={() => toggle(conflict.key)}
                    />
                    {conflict.table} · {conflict.sourceId} ({copy.skipLabel})
                  </label>
                </li>
              ))}
            </ul>
          </>
        )}
      </section>

      {canExecute ? (
        <form action={formAction} aria-label={copy.executeTitle}>
          <input type="hidden" name="sourceId" value={sourceId} />
          <input type="hidden" name="canonicalId" value={canonicalId} />
          <input
            type="hidden"
            name="resolutions"
            value={JSON.stringify(
              Object.fromEntries(impact.conflicts.map((conflict) => [conflict.key, "skip"])),
            )}
          />
          <input
            type="hidden"
            name="expectedVersions"
            value={JSON.stringify({
              source: impact.source.updatedAt,
              canonical: impact.canonical.updatedAt,
            })}
          />
          <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
          <label htmlFor="merge-reason">{copy.reasonLabel}</label>
          <textarea
            id="merge-reason"
            name="reason"
            required
            minLength={1}
            maxLength={2000}
            placeholder={copy.reasonPlaceholder}
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
            disabled={pending || !allAcknowledged}
            aria-busy={pending}
            aria-describedby={!allAcknowledged ? "merge-conflicts" : undefined}
          >
            {copy.execute}
          </Button>
        </form>
      ) : (
        <p role="note">{copy.adminOnly}</p>
      )}
    </div>
  );
}
