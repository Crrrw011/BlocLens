"use client";

import * as DialogPrimitive from "@radix-ui/react-dialog";
import { X } from "@phosphor-icons/react";
import { createContext, useCallback, useContext, useEffect, useState } from "react";

import { en } from "@/lib/messages/en";

import { LayerContext } from "./layer-context";

type DialogProps = React.ComponentProps<typeof DialogPrimitive.Root>;

type DialogContentProps = Readonly<{
  title: string;
  description?: string;
  children: React.ReactNode;
}>;

const DialogCloseContext = createContext<(() => void) | null>(null);

function LayerRegistration() {
  const registerLayer = useContext(LayerContext);
  const closeLayer = useContext(DialogCloseContext);

  useEffect(
    () => (closeLayer ? registerLayer?.(closeLayer) : undefined),
    [closeLayer, registerLayer],
  );
  return null;
}

export function Dialog({
  children,
  open: controlledOpen,
  defaultOpen = false,
  onOpenChange,
  ...props
}: DialogProps) {
  const [uncontrolledOpen, setUncontrolledOpen] = useState(defaultOpen);
  const open = controlledOpen ?? uncontrolledOpen;
  const handleOpenChange = useCallback(
    (nextOpen: boolean) => {
      if (controlledOpen === undefined) setUncontrolledOpen(nextOpen);
      onOpenChange?.(nextOpen);
    },
    [controlledOpen, onOpenChange],
  );
  const close = useCallback(() => handleOpenChange(false), [handleOpenChange]);

  return (
    <DialogCloseContext.Provider value={close}>
      <DialogPrimitive.Root {...props} open={open} onOpenChange={handleOpenChange}>
        {children}
      </DialogPrimitive.Root>
    </DialogCloseContext.Provider>
  );
}

export function DialogContent({ title, description, children }: DialogContentProps) {
  return (
    <DialogPrimitive.Portal>
      <DialogPrimitive.Overlay className="dialog__overlay" />
      <DialogPrimitive.Content className="dialog__content">
        <LayerRegistration />
        <div className="dialog__header">
          <DialogPrimitive.Title>{title}</DialogPrimitive.Title>
          <DialogPrimitive.Close className="icon-button focus-ring" aria-label={en.shell.closeDetails}>
            <X aria-hidden="true" size={20} />
          </DialogPrimitive.Close>
        </div>
        {description ? (
          <DialogPrimitive.Description className="dialog__description">
            {description}
          </DialogPrimitive.Description>
        ) : null}
        {children}
      </DialogPrimitive.Content>
    </DialogPrimitive.Portal>
  );
}

export const DialogTrigger = DialogPrimitive.Trigger;
export const DialogClose = DialogPrimitive.Close;
