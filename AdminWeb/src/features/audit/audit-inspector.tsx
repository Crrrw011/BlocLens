"use client";

import { useEffect, useState } from "react";

import { Inspector } from "@/components/shell/inspector";
import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import type { AuditEvent } from "./export";

const copy = en.audit.inspector;

function SummaryValue({ value }: Readonly<{ value: unknown }>) {
  if (value === null || value === undefined) return <>—</>;
  if (typeof value === "object") return <>{JSON.stringify(value)}</>;
  return <>{String(value)}</>;
}

export function AuditInspector({
  event,
  triggerRef,
  onClose,
}: Readonly<{
  event: AuditEvent | null;
  triggerRef?: React.RefObject<HTMLElement | null>;
  onClose: () => void;
}>) {
  const [open, setOpen] = useState(event !== null);

  useEffect(() => {
    setOpen(event !== null);
  }, [event]);

  if (event === null) return null;

  const close = () => {
    setOpen(false);
    onClose();
  };

  return (
    <Inspector
      open={open}
      title={copy.title}
      triggerRef={triggerRef}
      onOpenChange={(next) => {
        if (!next) close();
      }}
    >
      <p>
        <StatusBadge tone="neutral">{event.actionKey}</StatusBadge>{" "}
        <StatusBadge tone={event.outcome === "succeeded" ? "success" : "danger"}>
          {event.outcome}
        </StatusBadge>
      </p>
      <dl>
        <div className="inspector-detail">
          <dt>{copy.reason}</dt>
          <dd>{event.reason === "" ? "—" : event.reason}</dd>
        </div>
        <div className="inspector-detail">
          <dt>{en.audit.table.columns.time}</dt>
          <dd>{event.createdAt}</dd>
        </div>
      </dl>
      <section aria-label={copy.before}>
        <h3>{copy.before}</h3>
        <dl>
          {Object.entries(event.beforeSummary).map(([key, value]) => (
            <div className="inspector-detail" key={key}>
              <dt>{key.replaceAll("_", " ")}</dt>
              <dd>
                <SummaryValue value={value} />
              </dd>
            </div>
          ))}
        </dl>
      </section>
      <section aria-label={copy.after}>
        <h3>{copy.after}</h3>
        <dl>
          {Object.entries(event.afterSummary).map(([key, value]) => (
            <div className="inspector-detail" key={key}>
              <dt>{key.replaceAll("_", " ")}</dt>
              <dd>
                <SummaryValue value={value} />
              </dd>
            </div>
          ))}
        </dl>
      </section>
    </Inspector>
  );
}
