"use client";

import { X } from "@phosphor-icons/react";
import { useEffect, useId, useRef } from "react";

import { en } from "@/lib/messages/en";

type InspectorProps = Readonly<{
  open: boolean;
  title: string;
  children: React.ReactNode;
  onOpenChange: (open: boolean) => void;
  triggerRef?: React.RefObject<HTMLElement | null>;
  footer?: React.ReactNode;
}>;

export function Inspector({
  open,
  title,
  children,
  onOpenChange,
  triggerRef,
  footer,
}: InspectorProps) {
  const titleId = useId();
  const closeRef = useRef<HTMLButtonElement>(null);
  const wasOpenRef = useRef(false);

  useEffect(() => {
    if (open) {
      closeRef.current?.focus();
      wasOpenRef.current = true;
      return;
    }

    if (wasOpenRef.current) {
      triggerRef?.current?.focus();
      wasOpenRef.current = false;
    }
  }, [open, triggerRef]);

  useEffect(() => {
    if (!open) return;

    function closeOnEscape(event: KeyboardEvent) {
      if (event.key === "Escape") onOpenChange(false);
    }

    document.addEventListener("keydown", closeOnEscape);
    return () => document.removeEventListener("keydown", closeOnEscape);
  }, [onOpenChange, open]);

  return (
    <>
      <button
        className="inspector-backdrop"
        data-open={open}
        type="button"
        tabIndex={-1}
        aria-hidden="true"
        onClick={() => onOpenChange(false)}
      />
      <aside
        className="inspector"
        data-open={open}
        aria-labelledby={titleId}
        aria-hidden={!open}
        inert={!open}
      >
        <header className="inspector__header">
          <h2 id={titleId}>{title}</h2>
          <button
            ref={closeRef}
            className="icon-button focus-ring"
            type="button"
            aria-label={en.shell.closeDetails}
            onClick={() => onOpenChange(false)}
          >
            <X aria-hidden="true" size={20} />
          </button>
        </header>
        <div className="inspector__body">{children}</div>
        {footer ? <footer className="inspector__footer">{footer}</footer> : null}
      </aside>
    </>
  );
}
