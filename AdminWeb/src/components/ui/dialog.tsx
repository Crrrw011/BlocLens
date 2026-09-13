"use client";

import * as DialogPrimitive from "@radix-ui/react-dialog";
import { X } from "@phosphor-icons/react";

import { en } from "@/lib/messages/en";

type DialogProps = Readonly<{
  open: boolean;
  title: string;
  description?: string;
  children: React.ReactNode;
  onOpenChange: (open: boolean) => void;
}>;

export function Dialog({ open, title, description, children, onOpenChange }: DialogProps) {
  return (
    <DialogPrimitive.Root open={open} onOpenChange={onOpenChange}>
      <DialogPrimitive.Portal>
        <DialogPrimitive.Overlay className="dialog__overlay" />
        <DialogPrimitive.Content className="dialog__content">
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
    </DialogPrimitive.Root>
  );
}

export const DialogTrigger = DialogPrimitive.Trigger;
export const DialogClose = DialogPrimitive.Close;
