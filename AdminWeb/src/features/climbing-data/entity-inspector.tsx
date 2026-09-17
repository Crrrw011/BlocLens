"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

import { Inspector } from "@/components/shell/inspector";
import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import type { EntityDetail, EntityKind } from "./types";

const copy = en.climbingData.inspector;

function formatValue(value: unknown): string {
  if (value === null || value === undefined) return "—";
  if (Array.isArray(value)) return value.length === 0 ? "—" : value.map(String).join(", ");
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
}

export function EntityInspector({
  kind,
  item,
  isAdmin,
  triggerRef,
  onClose,
}: Readonly<{
  kind: EntityKind;
  item: EntityDetail | "unavailable" | null;
  isAdmin: boolean;
  triggerRef?: React.RefObject<HTMLElement | null>;
  onClose: () => void;
}>) {
  const [open, setOpen] = useState(item !== null);

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
      footer={
        <>
          <Link href={`/climbing-data/${kind}/${item.id}`}>{copy.openFull}</Link>
          {isAdmin &&
          (kind === "route" ||
            kind === "route_photo" ||
            kind === "beta_link" ||
            kind === "route_comment") &&
          item.status !== "active" ? (
            <>
              {" · "}
              <Link href={`/climbing-data/${kind}/${item.id}#entity-delete`}>
                {en.climbingData.deletion.trigger}
              </Link>
            </>
          ) : null}
        </>
      }
    >
      <p>
        <StatusBadge tone="neutral">{item.status}</StatusBadge>{" "}
        {item.subtitle}
      </p>
      <dl>
        {Object.entries(item.details)
          .filter(([, value]) => value !== null && value !== undefined && value !== "")
          .slice(0, 12)
          .map(([key, value]) => (
            <div className="inspector-detail" key={key}>
              <dt>{key.replaceAll("_", " ")}</dt>
              <dd>{formatValue(value)}</dd>
            </div>
          ))}
      </dl>
      <section aria-label={copy.moderationHistory}>
        <h3>{copy.moderationHistory}</h3>
        {item.moderationHistory.length === 0 ? (
          <p>{copy.noHistory}</p>
        ) : (
          <ul>
            {item.moderationHistory.map((entry) => (
              <li key={entry.id}>
                {entry.actionType} · {entry.createdAt}
              </li>
            ))}
          </ul>
        )}
      </section>
    </Inspector>
  );
}
