import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { useRef, useState } from "react";
import { describe, expect, it } from "vitest";

import { Inspector } from "@/components/shell/inspector";

import { Dialog, DialogContent, DialogTrigger } from "./dialog";

function DialogHarness() {
  const [open, setOpen] = useState(false);

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <button type="button">Open confirmation</button>
      </DialogTrigger>
      <DialogContent title="Confirm review">
        <button type="button">Continue</button>
      </DialogContent>
    </Dialog>
  );
}

function LayeredDialogHarness() {
  const inspectorTriggerRef = useRef<HTMLButtonElement>(null);
  const [inspectorOpen, setInspectorOpen] = useState(false);
  const [dialogOpen, setDialogOpen] = useState(false);

  return (
    <>
      <button
        ref={inspectorTriggerRef}
        type="button"
        onClick={() => setInspectorOpen(true)}
      >
        Open case
      </button>
      <Inspector
        open={inspectorOpen}
        title="Case details"
        triggerRef={inspectorTriggerRef}
        onOpenChange={setInspectorOpen}
      >
        <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
          <DialogTrigger asChild>
            <button type="button">Open decision</button>
          </DialogTrigger>
          <DialogContent title="Review decision">
            <button type="button">Confirm</button>
          </DialogContent>
        </Dialog>
      </Inspector>
    </>
  );
}

describe("Dialog", () => {
  it("restores focus to the control that opened it after a true open and close cycle", async () => {
    render(<DialogHarness />);

    const trigger = screen.getByRole("button", { name: "Open confirmation" });
    fireEvent.click(trigger);

    const close = await screen.findByRole("button", { name: "Close details" });
    await waitFor(() => expect(close).toHaveFocus());
    fireEvent.click(close);

    await waitFor(() => expect(trigger).toHaveFocus());
  });

  it("lets Escape close only the nested top-layer dialog", async () => {
    render(<LayeredDialogHarness />);

    fireEvent.click(screen.getByRole("button", { name: "Open case" }));
    fireEvent.click(screen.getByRole("button", { name: "Open decision" }));
    expect(await screen.findByRole("dialog", { name: "Review decision" })).toBeInTheDocument();

    fireEvent.keyDown(document, { key: "Escape", code: "Escape" });

    await waitFor(() => {
      expect(screen.queryByRole("dialog", { name: "Review decision" })).not.toBeInTheDocument();
    });
    expect(screen.getByRole("button", { name: "Close details" })).toBeInTheDocument();
  });
});
