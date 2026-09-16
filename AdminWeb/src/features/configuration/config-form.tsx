"use client";

import { useActionState, useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { en } from "@/lib/messages/en";
import { updateConfiguration } from "./actions";

const copy = en.configuration;

export type ConfigEntry = {
  key: "review.queue.order" | "overview.default_range" | "flags.moderation_notes" | "copy.reason_templates";
  value: unknown;
  version: number;
};

const ORDERS = ["newest_first", "oldest_first", "severity_first"] as const;
const RANGES = ["7d", "30d", "90d"] as const;

function initialJson(key: ConfigEntry["key"], value: unknown): string {
  if (key === "copy.reason_templates" && Array.isArray(value)) {
    return JSON.stringify(
      value.filter((line): line is string => typeof line === "string"),
    );
  }
  return JSON.stringify(value);
}

export function ConfigForm({ entry }: Readonly<{ entry: ConfigEntry }>) {
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [jsonValue, setJsonValue] = useState(() => initialJson(entry.key, entry.value));
  const [templates, setTemplates] = useState(() =>
    entry.key === "copy.reason_templates" && Array.isArray(entry.value)
      ? entry.value.filter((line): line is string => typeof line === "string").join("\n")
      : "",
  );
  const [state, formAction, pending] = useActionState(updateConfiguration, { status: "idle" });
  const conflicted = state.status === "error" && "conflict" in state;

  // A confirmed submission retires its key at once: the next submit is a
  // new attempt and must pass the version guard instead of replaying.
  useEffect(() => {
    if (state.status === "success") setIdempotencyKey(crypto.randomUUID());
  }, [state]);

  return (
    <form
      action={formAction}
      aria-label={entry.key}
    >
      <input type="hidden" name="key" value={entry.key} />
      <input type="hidden" name="expectedVersion" value={entry.version} />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      <input type="hidden" name="value" value={jsonValue} />

      {entry.key === "review.queue.order" ? (
        <>
          <label htmlFor={`config-${entry.key}`}>{copy.fields.queueOrder}</label>
          <select
            id={`config-${entry.key}`}
            value={JSON.parse(jsonValue) as string}
            onChange={(event) => setJsonValue(JSON.stringify(event.target.value))}
          >
            {ORDERS.map((option) => (
              <option key={option} value={option}>
                {copy.fields.orders[option]}
              </option>
            ))}
          </select>
        </>
      ) : null}

      {entry.key === "overview.default_range" ? (
        <fieldset>
          <legend>{copy.fields.defaultRange}</legend>
          {RANGES.map((option) => (
            <label key={option}>
              <input
                type="radio"
                name={`range-${entry.key}`}
                checked={JSON.parse(jsonValue) === option}
                onChange={() => setJsonValue(JSON.stringify(option))}
              />
              {option}
            </label>
          ))}
        </fieldset>
      ) : null}

      {entry.key === "flags.moderation_notes" ? (
        <label>
          <input
            type="checkbox"
            checked={JSON.parse(jsonValue) === true}
            onChange={(event) => setJsonValue(JSON.stringify(event.target.checked))}
          />
          {copy.fields.moderationNotes}
        </label>
      ) : null}

      {entry.key === "copy.reason_templates" ? (
        <>
          <label htmlFor={`config-${entry.key}`}>{copy.fields.templates}</label>
          <textarea
            id={`config-${entry.key}`}
            value={templates}
            onChange={(event) => {
              setTemplates(event.target.value);
              setJsonValue(
                JSON.stringify(
                  event.target.value
                    .split("\n")
                    .map((line) => line.trim())
                    .filter((line) => line !== ""),
                ),
              );
            }}
            rows={4}
            maxLength={2200}
          />
        </>
      ) : null}

      <label htmlFor={`config-reason-${entry.key}`}>{copy.reasonLabel}</label>
      <input
        id={`config-reason-${entry.key}`}
        name="reason"
        type="text"
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
        {state.status === "success" ? <p role="status">Saved</p> : null}
      </div>
      <Button type="submit" disabled={pending} aria-busy={pending}>
        {copy.save}
      </Button>
    </form>
  );
}
