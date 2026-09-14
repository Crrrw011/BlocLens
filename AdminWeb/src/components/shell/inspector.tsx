"use client";

import * as DialogPrimitive from "@radix-ui/react-dialog";
import { X } from "@phosphor-icons/react";
import { useCallback, useEffect, useRef, useSyncExternalStore } from "react";

import { en } from "@/lib/messages/en";
import { LayerContext } from "@/components/ui/layer-context";

type InspectorProps = Readonly<{
  open: boolean;
  title: string;
  children: React.ReactNode;
  onOpenChange: (open: boolean) => void;
  triggerRef?: React.RefObject<HTMLElement | null>;
  footer?: React.ReactNode;
}>;

const overlayMediaQuery = "(max-width: 1279px)";

function subscribeToOverlayMode(onChange: () => void) {
  if (typeof window === "undefined" || typeof window.matchMedia !== "function") {
    return () => undefined;
  }

  const mediaQuery = window.matchMedia(overlayMediaQuery);
  mediaQuery.addEventListener("change", onChange);
  return () => mediaQuery.removeEventListener("change", onChange);
}

function getOverlayMode() {
  return typeof window !== "undefined" &&
    typeof window.matchMedia === "function" &&
    window.matchMedia(overlayMediaQuery).matches;
}

function clearBackgroundInert() {
  document.querySelector<HTMLElement>(".app-shell")?.removeAttribute("inert");
}

export function Inspector({
  open,
  title,
  children,
  onOpenChange,
  triggerRef,
  footer,
}: InspectorProps) {
  const closeRef = useRef<HTMLButtonElement>(null);
  const nestedLayersRef = useRef<Array<() => void>>([]);
  const isOverlay = useSyncExternalStore(subscribeToOverlayMode, getOverlayMode, () => false);
  const registerNestedLayer = useCallback((closeLayer: () => void) => {
    nestedLayersRef.current.push(closeLayer);
    return () => {
      nestedLayersRef.current = nestedLayersRef.current.filter((close) => close !== closeLayer);
    };
  }, []);

  useEffect(() => {
    if (!open) return;

    const appShell = document.querySelector<HTMLElement>(".app-shell");
    if (isOverlay) {
      appShell?.setAttribute("inert", "");
    } else {
      appShell?.removeAttribute("inert");
    }

    return clearBackgroundInert;
  }, [isOverlay, open]);

  return (
    <DialogPrimitive.Root open={open} onOpenChange={onOpenChange} modal={isOverlay}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay className="inspector-backdrop" />
        <DialogPrimitive.Content
          className="inspector"
          data-inspector-mode={isOverlay ? "overlay" : "wide"}
          onOpenAutoFocus={(event) => {
            event.preventDefault();
            closeRef.current?.focus();
          }}
          onCloseAutoFocus={(event) => {
            clearBackgroundInert();
            if (triggerRef?.current) {
              event.preventDefault();
              triggerRef.current.focus();
            }
          }}
          onEscapeKeyDown={(event) => {
            const closeTopLayer = nestedLayersRef.current.at(-1);
            if (closeTopLayer) {
              event.preventDefault();
              closeTopLayer();
            }
          }}
          onInteractOutside={(event) => {
            if (!isOverlay) event.preventDefault();
          }}
        >
          <LayerContext.Provider value={registerNestedLayer}>
            <header className="inspector__header">
              <DialogPrimitive.Title>{title}</DialogPrimitive.Title>
              <DialogPrimitive.Close
                ref={closeRef}
                className="icon-button focus-ring"
                aria-label={en.shell.closeDetails}
              >
                <X aria-hidden="true" size={20} />
              </DialogPrimitive.Close>
            </header>
            <div className="inspector__body">{children}</div>
            {footer ? <footer className="inspector__footer">{footer}</footer> : null}
          </LayerContext.Provider>
        </DialogPrimitive.Content>
      </DialogPrimitive.Portal>
    </DialogPrimitive.Root>
  );
}
