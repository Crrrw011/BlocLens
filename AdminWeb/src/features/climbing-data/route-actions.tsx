"use client";

import { useState } from "react";

import { Button } from "@/components/ui/button";
import { en } from "@/lib/messages/en";
import { LifecycleDialog } from "./lifecycle-dialog";

const copy = en.climbingData.lifecycle;

type Action = "archive" | "unarchive" | "hide" | "unhide";

export function RouteActions({
  routeId,
  lifecycle,
  moderation,
  expectedUpdatedAt,
  isAdmin,
}: Readonly<{
  routeId: string;
  lifecycle: string;
  moderation: string;
  expectedUpdatedAt: string;
  isAdmin: boolean;
}>) {
  const [action, setAction] = useState<Action | null>(null);

  const available: Action[] = [];
  if (isAdmin && lifecycle === "active") available.push("archive");
  if (isAdmin && lifecycle === "archived") available.push("unarchive");
  if (moderation === "visible") available.push("hide");
  if (moderation === "temporarily_hidden") available.push("unhide");

  if (available.length === 0) return null;

  return (
    <div>
      {available.map((option) => (
        <Button key={option} type="button" onClick={() => setAction(option)}>
          {copy.actions[option]}
        </Button>
      ))}
      {action ? (
        <LifecycleDialog
          routeId={routeId}
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
