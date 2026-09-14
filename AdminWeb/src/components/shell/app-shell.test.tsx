import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { useRef, useState } from "react";
import { describe, expect, it, vi } from "vitest";

import { AppShell } from "./app-shell";
import { Inspector } from "./inspector";

vi.mock("next/navigation", () => ({
  usePathname: () => "/overview",
}));

const administrator = {
  userId: "administrator-id",
  role: "admin" as const,
  canManageAdministrators: true,
};

const moderator = {
  userId: "moderator-id",
  role: "moderator" as const,
  canManageAdministrators: false,
};

describe("AppShell", () => {
  it("gives Administrators six labelled primary destinations", () => {
    render(<AppShell access={administrator}>Workspace</AppShell>);

    const navigation = screen.getByRole("navigation", { name: "Primary navigation" });
    expect(navigation).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Overview" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Review" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Climbing Data" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "People and Access" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Audit" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Configuration" })).toBeInTheDocument();
  });

  it("keeps notifications and account controls at the bottom of the rail", () => {
    render(<AppShell access={administrator}>Workspace</AppShell>);

    const bottomControls = screen.getByTestId("rail-bottom-controls");
    expect(bottomControls).toContainElement(
      screen.getByRole("button", { name: "Notifications" }),
    );
    expect(bottomControls).toContainElement(
      screen.getByRole("button", { name: "Open account menu" }),
    );
  });

  it("keeps Administrator-only destinations hidden from Moderators", () => {
    render(<AppShell access={moderator}>Workspace</AppShell>);

    expect(screen.queryByRole("link", { name: "People and Access" })).not.toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Configuration" })).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Review" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Climbing Data" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Audit" })).toBeInTheDocument();
  });

  it("exposes rail destinations to sequential keyboard focus", () => {
    render(<AppShell access={administrator}>Workspace</AppShell>);

    const overview = screen.getByRole("link", { name: "Overview" });
    overview.focus();

    expect(overview).toHaveFocus();
    expect(overview).toHaveClass("focus-ring");
  });

  it("registers sign out as a keyboard-activatable account-menu item", async () => {
    const signOutAction = vi.fn(async () => undefined);
    render(
      <AppShell access={administrator} signOutAction={signOutAction}>
        Workspace
      </AppShell>,
    );

    const accountMenu = screen.getByRole("button", { name: "Open account menu" });
    accountMenu.focus();
    fireEvent.keyDown(accountMenu, { key: "Enter", code: "Enter" });

    const signOut = await screen.findByRole("menuitem", { name: "Sign out" });
    expect(signOut).toHaveFocus();

    fireEvent.keyDown(signOut, { key: "Enter", code: "Enter" });
    await waitFor(() => expect(signOutAction).toHaveBeenCalledOnce());
  });
});

function InspectorHarness() {
  const triggerRef = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);

  return (
    <>
      <button ref={triggerRef} type="button" onClick={() => setOpen(true)}>
        Open details
      </button>
      <Inspector
        open={open}
        title="Case details"
        triggerRef={triggerRef}
        onOpenChange={setOpen}
      >
        Inspector content
      </Inspector>
    </>
  );
}

describe("Inspector", () => {
  it("restores focus to its trigger when closed", async () => {
    render(<InspectorHarness />);

    const trigger = screen.getByRole("button", { name: "Open details" });
    fireEvent.click(trigger);
    fireEvent.click(screen.getByRole("button", { name: "Close details" }));

    await waitFor(() => expect(trigger).toHaveFocus());
  });
});
