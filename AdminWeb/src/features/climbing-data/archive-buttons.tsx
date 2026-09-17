"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { en } from "@/lib/messages/en";
import type { EntityKind } from "./types";
import { VisibilityDialog, type VisibilityAction } from "./visibility-dialog";

const copy = en.climbingData.visibility;

type ArchivableKind = Extract<
  EntityKind,
  "wall_zone" | "route_photo" | "beta_link" | "route_comment"
>;

function availableActions(kind: ArchivableKind, status: string, isAdmin: boolean): VisibilityAction[] {
  const actions: VisibilityAction[] = [];
  if (kind === "wall_zone") {
    if (isAdmin && status === "active") actions.push("archive");
    if (isAdmin && status === "archived") actions.push("unarchive");
    return actions;
  }
  if (status === "visible") {
    if (isAdmin) actions.push("archive");
    actions.push("hide");
  }
  if (status === "hidden") {
    actions.push("unhide");
  }
  if (status === "archived" && isAdmin) {
    actions.push("unarchive");
  }
  return actions;
}

export function ArchiveButtons({
  kind,
  id,
  status,
  expectedUpdatedAt,
  isAdmin,
}: Readonly<{
  kind: ArchivableKind;
  id: string;
  status: string;
  expectedUpdatedAt: string;
  isAdmin: boolean;
}>) {
  const [action, setAction] = useState<VisibilityAction | null>(null);
  const actions = availableActions(kind, status, isAdmin);

  if (actions.length === 0) return null;

  return (
    <div>
      {actions.map((option) => (
        <Button key={option} type="button" onClick={() => setAction(option)}>
          {copy.actions[option]}
        </Button>
      ))}
      {action ? (
        <VisibilityDialog
          kind={kind}
          id={id}
          action={action}
          expectedUpdatedAt={expectedUpdatedAt}
          open={action !== null}
          onOpenChange={(next) => {
            if (!next) setAction(null);
          }}
        />
      ) : null}
    </div>
  );
}
