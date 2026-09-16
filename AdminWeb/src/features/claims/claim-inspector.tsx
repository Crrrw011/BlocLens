"use client";

import { useEffect, useState } from "react";

import { Inspector } from "@/components/shell/inspector";
import { Button } from "@/components/ui/button";
import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import { ClaimDialog } from "./claim-dialog";

const copy = en.people.claims;

export type ClaimRow = {
  id: string;
  gymId: string;
  gymName: string;
  applicantId: string | null;
  applicantName: string;
  domainEmail: string;
  verificationMethod: string;
  status: string;
  reviewNote: string | null;
  updatedAt: string;
  createdAt: string;
};

export function ClaimInspector({
  claim,
  triggerRef,
  onClose,
}: Readonly<{
  claim: ClaimRow | "unavailable" | null;
  triggerRef?: React.RefObject<HTMLElement | null>;
  onClose: () => void;
}>) {
  const [open, setOpen] = useState(claim !== null);
  const [decision, setDecision] = useState<"approved" | "rejected" | null>(null);

  useEffect(() => {
    setOpen(claim !== null);
  }, [claim]);

  if (claim === null) return null;

  const close = () => {
    setOpen(false);
    onClose();
  };

  if (claim === "unavailable") {
    return (
      <Inspector
        open={open}
        title={copy.title}
        triggerRef={triggerRef}
        onOpenChange={(next) => {
          if (!next) close();
        }}
      >
        <p>{en.people.detail.unavailableBody}</p>
      </Inspector>
    );
  }

  const decidable = claim.status === "submitted";

  return (
    <Inspector
      open={open}
      title={copy.title}
      triggerRef={triggerRef}
      onOpenChange={(next) => {
        if (!next) close();
      }}
      footer={
        decidable ? (
          <>
            <Button type="button" onClick={() => setDecision("approved")}>
              {copy.approve}
            </Button>
            <Button type="button" onClick={() => setDecision("rejected")}>
              {copy.reject}
            </Button>
          </>
        ) : undefined
      }
    >
      <p>
        <StatusBadge tone={claim.status === "submitted" ? "warning" : "neutral"}>
          {claim.status}
        </StatusBadge>
      </p>
      <dl>
        <div className="inspector-detail">
          <dt>{copy.columns.gym}</dt>
          <dd>{claim.gymName}</dd>
        </div>
        <div className="inspector-detail">
          <dt>{copy.columns.applicant}</dt>
          <dd>{`${claim.applicantName} · ${claim.domainEmail}`}</dd>
        </div>
        <div className="inspector-detail">
          <dt>{copy.columns.method}</dt>
          <dd>
            {copy.methods[claim.verificationMethod as keyof typeof copy.methods] ??
              claim.verificationMethod}
          </dd>
        </div>
        <div className="inspector-detail">
          <dt>{en.people.detail.memberSince}</dt>
          <dd>{claim.createdAt.slice(0, 10)}</dd>
        </div>
      </dl>
      {decision ? (
        <ClaimDialog
          claimId={claim.id}
          decision={decision}
          expectedUpdatedAt={claim.updatedAt}
          open={decision !== null}
          onOpenChange={(next) => {
            if (!next) setDecision(null);
          }}
        />
      ) : null}
    </Inspector>
  );
}
