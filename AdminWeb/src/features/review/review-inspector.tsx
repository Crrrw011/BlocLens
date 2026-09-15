"use client";

import { useEffect, useState } from "react";

import { Inspector } from "@/components/shell/inspector";
import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import { ActionDialog } from "./action-dialog";
import type { ReviewDecision, ReviewItemDetail, ReviewKind } from "./types";

const copy = en.review.inspector;
const decisionCopy = en.review.decisions;

function allowedDecisions(kind: ReviewKind, canAccept: boolean): ReviewDecision[] {
  switch (kind) {
    case "content_report":
      return ["dismiss", "escalate", "hide", "restore"];
    case "route_correction":
      return canAccept
        ? ["escalate", "accept_correction", "reject_correction"]
        : ["escalate", "reject_correction"];
    case "removal_report":
      return ["dismiss", "escalate"];
    case "merge_suggestion":
      return canAccept ? ["accept_correction", "reject_correction"] : ["reject_correction"];
  }
}

export type InspectorItem = ReviewItemDetail;

function DetailRow({ label, value }: Readonly<{ label: string; value: string }>) {
  return (
    <div className="inspector-detail">
      <dt>{label}</dt>
      <dd>{value}</dd>
    </div>
  );
}

export function ReviewInspector({
  item,
  canSeeReporter,
  canAccept,
  triggerRef,
  onClose,
}: Readonly<{
  item: InspectorItem | "unavailable" | null;
  canSeeReporter: boolean;
  canAccept: boolean;
  triggerRef?: React.RefObject<HTMLElement | null>;
  onClose: () => void;
}>) {
  const [open, setOpen] = useState(item !== null);
  const [decision, setDecision] = useState<ReviewDecision | null>(null);

  useEffect(() => {
    setOpen(item !== null);
  }, [item]);

  if (item === null) return null;

  const close = () => {
    setOpen(false);
    onClose();
  };

  if (item === "unavailable") {
    return (
      <Inspector
        open={open}
        title={copy.unavailableTitle}
        triggerRef={triggerRef}
        onOpenChange={(next) => {
          if (!next) close();
        }}
      >
        <p>{copy.unavailableBody}</p>
      </Inspector>
    );
  }

  return (
    <Inspector
      open={open}
      title={copy.title}
      triggerRef={triggerRef}
      onOpenChange={(next) => {
        if (!next) close();
      }}
      footer={allowedDecisions(item.kind, canAccept).map((action) => (
        <button key={action} type="button" onClick={() => setDecision(action)}>
          {decisionCopy.actions[action]}
        </button>
      ))}
    >
      <p>
        <StatusBadge tone={item.severity === "severe" ? "danger" : "neutral"}>
          {item.severity}
        </StatusBadge>{" "}
        <StatusBadge tone={item.status === "open" ? "warning" : "neutral"}>
          {item.status}
        </StatusBadge>
      </p>
      <dl>
        <DetailRow label={copy.context} value={item.routeLabel ?? item.gymName ?? item.targetType} />
        <DetailRow label={copy.evidence} value={item.summary === "" ? item.title : item.summary} />
        {canSeeReporter && item.reporterId ? (
          <DetailRow label={copy.reportedBy} value={item.reporterId} />
        ) : null}
        {item.reviewedBy ? (
          <DetailRow label={copy.reviewedBy} value={item.reviewedBy} />
        ) : null}
      </dl>
      <section aria-label={copy.priorActions}>
        <h3>{copy.priorActions}</h3>
        {item.priorActions.length === 0 ? (
          <p>{copy.noPriorActions}</p>
        ) : (
          <ul>
            {item.priorActions.map((action) => (
              <li key={action.id}>
                {action.actionType} · {action.createdAt}
              </li>
            ))}
          </ul>
        )}
      </section>
      {decision ? (
        <ActionDialog
          kind={item.kind}
          id={item.id}
          title={item.title}
          decision={decision}
          expectedUpdatedAt={item.updatedAt}
          open={decision !== null}
          onOpenChange={(next) => {
            if (!next) setDecision(null);
          }}
        />
      ) : null}
    </Inspector>
  );
}
