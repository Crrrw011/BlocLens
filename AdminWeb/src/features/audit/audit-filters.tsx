"use client";

import { useState } from "react";

import { en } from "@/lib/messages/en";

const copy = en.audit.filters;

const OUTCOMES = ["succeeded", "rejected", "partially_failed", "failed"] as const;

export function AuditFilters({
  defaults,
  exportHref,
}: Readonly<{
  defaults: {
    actorId: string;
    action: string;
    targetType: string;
    outcome: string;
    from: string;
    to: string;
  };
  exportHref: string;
}>) {
  // datetime-local carries no offset; convert to ISO for the server contract.
  const [fromLocal, setFromLocal] = useState(defaults.from.slice(0, 16));
  const [toLocal, setToLocal] = useState(defaults.to.slice(0, 16));

  return (
    <form className="review-filters__search" method="get" action="/audit" role="search">
      <label htmlFor="audit-actor">{copy.actorLabel}</label>
      <input
        id="audit-actor"
        name="actor"
        type="text"
        defaultValue={defaults.actorId}
        placeholder={copy.actorPlaceholder}
        maxLength={36}
      />
      <label htmlFor="audit-action">{copy.actionLabel}</label>
      <input
        id="audit-action"
        name="action"
        type="text"
        defaultValue={defaults.action}
        maxLength={80}
      />
      <label htmlFor="audit-target">{copy.targetLabel}</label>
      <input
        id="audit-target"
        name="target"
        type="text"
        defaultValue={defaults.targetType}
        maxLength={80}
      />
      <label htmlFor="audit-outcome">{copy.outcomeLabel}</label>
      <select id="audit-outcome" name="outcome" defaultValue={defaults.outcome}>
        <option value="">{copy.anyOutcome}</option>
        {OUTCOMES.map((outcome) => (
          <option key={outcome} value={outcome}>
            {outcome}
          </option>
        ))}
      </select>
      <label htmlFor="audit-from-visible">{copy.fromLabel}</label>
      <input
        id="audit-from-visible"
        type="datetime-local"
        value={fromLocal}
        onChange={(event) => setFromLocal(event.target.value)}
        required
      />
      <input
        type="hidden"
        name="from"
        value={fromLocal === "" ? "" : new Date(fromLocal).toISOString()}
      />
      <label htmlFor="audit-to-visible">{copy.toLabel}</label>
      <input
        id="audit-to-visible"
        type="datetime-local"
        value={toLocal}
        onChange={(event) => setToLocal(event.target.value)}
        required
      />
      <input
        type="hidden"
        name="to"
        value={toLocal === "" ? "" : new Date(toLocal).toISOString()}
      />
      <button type="submit">{copy.searchSubmit}</button>
      <a href={exportHref}>{en.audit.export.action}</a>
    </form>
  );
}
