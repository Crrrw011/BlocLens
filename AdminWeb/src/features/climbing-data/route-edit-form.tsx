"use client";

import { useActionState, useEffect, useState } from "react";
import { useRouter } from "next/navigation";

import { Button } from "@/components/ui/button";
import { en } from "@/lib/messages/en";
import { updateEntity } from "./actions";

const copy = en.climbingData.edit;

const TERRAINS = ["slab", "vertical", "overhang", "roof", "cave", "mixed"] as const;

export function RouteEditForm({
  id,
  colour,
  gymGrade,
  terrain,
  subjectiveGrade,
  expectedUpdatedAt,
}: Readonly<{
  id: string;
  colour: string | null;
  gymGrade: number | null;
  terrain: string | null;
  subjectiveGrade: number | null;
  expectedUpdatedAt: string;
}>) {
  const router = useRouter();
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID());
  const [state, formAction, pending] = useActionState(updateEntity, { status: "idle" });

  useEffect(() => {
    if (state.status === "success") {
      setIdempotencyKey(crypto.randomUUID());
      router.refresh();
    }
  }, [state, router]);

  const conflicted = state.status === "error" && "conflict" in state;

  return (
    <form action={formAction} aria-label={copy.title}>
      <input type="hidden" name="kind" value="route" />
      <input type="hidden" name="id" value={id} />
      <input type="hidden" name="expectedUpdatedAt" value={expectedUpdatedAt} />
      <input type="hidden" name="idempotencyKey" value={idempotencyKey} />
      {/* Only whitelisted route fields are submitted; grades and counts stay server-owned. */}
      <label htmlFor={`route-colour-${id}`}>
        Colour
        <input
          id={`route-colour-${id}`}
          name="colour"
          type="text"
          defaultValue={colour ?? ""}
          maxLength={80}
          required
        />
      </label>
      <label htmlFor={`route-grade-${id}`}>
        Gym grade
        <input
          id={`route-grade-${id}`}
          name="gym_grade"
          type="number"
          min={-1}
          max={17}
          step={1}
          defaultValue={gymGrade ?? ""}
        />
      </label>
      <label htmlFor={`route-terrain-${id}`}>
        Terrain
        <select id={`route-terrain-${id}`} name="terrain" defaultValue={terrain ?? "slab"}>
          {TERRAINS.map((option) => (
            <option key={option} value={option}>
              {option}
            </option>
          ))}
        </select>
      </label>
      <label htmlFor={`route-subjective-${id}`}>
        Subjective grade
        <input
          id={`route-subjective-${id}`}
          name="subjective_grade"
          type="number"
          min={-1}
          max={17}
          step={1}
          defaultValue={subjectiveGrade ?? ""}
          placeholder="unset"
        />
      </label>
      <label htmlFor={`route-reason-${id}`}>
        {copy.reasonLabel}
        <input
          id={`route-reason-${id}`}
          name="reason"
          type="text"
          required
          minLength={1}
          maxLength={2000}
          placeholder={copy.reasonPlaceholder}
        />
      </label>
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
