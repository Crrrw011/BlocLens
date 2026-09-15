import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { useRef, useState } from "react";
import { describe, expect, it, vi } from "vitest";

import { ReviewFilters } from "./review-filters";
import { ReviewInspector } from "./review-inspector";
import { ReviewTable } from "./review-table";
import type { ReviewItemDetail, ReviewQueueItem } from "./types";

const { push } = vi.hoisted(() => ({ push: vi.fn() }));
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push }),
  usePathname: () => "/review",
  useSearchParams: () => new URLSearchParams("status=pending&kind=all"),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => {
    throw new Error("network clients are unavailable in view tests");
  },
}));

function item(overrides: Partial<ReviewQueueItem> = {}): ReviewQueueItem {
  return {
    kind: "content_report",
    id: "96000000-0000-4000-8000-000000000001",
    status: "open",
    severity: "severe",
    routeId: "30000000-0000-4000-8000-000000000001",
    routeLabel: "Blue",
    gymName: "Urban Climb West End",
    targetType: "route",
    targetId: "30000000-0000-4000-8000-000000000001",
    title: "harassment",
    summary: "Severe report fixture",
    createdAt: "2026-09-10T00:00:00.000Z",
    updatedAt: "2026-09-10T00:00:00.000Z",
    ...overrides,
  };
}

function detail(overrides: Partial<ReviewItemDetail> = {}): ReviewItemDetail {
  return {
    ...item(),
    details: { category: "harassment" },
    reporterId: "90000000-0000-4000-8000-000000000001",
    reviewedBy: null,
    reviewedAt: null,
    priorActions: [],
    ...overrides,
  };
}

describe("ReviewFilters", () => {
  it("marks the current filters and preserves them through search", () => {
    render(
      <ReviewFilters
        current={{ status: "pending", kind: "content_report", severity: "severe", q: "Blue" }}
      />,
    );
    expect(screen.getByRole("link", { name: "Pending" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByRole("link", { name: "Reports" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByDisplayValue("Blue")).toBeInTheDocument();
    const form = screen.getByRole("search");
    expect(form).toHaveAttribute("method", "get");
    expect(form).toHaveAttribute("action", "/review");
  });
});

describe("ReviewTable", () => {
  it("changes only the selection when a row is activated", () => {
    push.mockReset();
    render(
      <ReviewTable items={[item()]} nextCursor={null} selected={null} canSeeReporter canAccept />,
    );
    fireEvent.click(screen.getByRole("cell", { name: "harassment" }));
    expect(push).toHaveBeenCalledOnce();
    const href = push.mock.calls[0]?.[0] as string;
    expect(href).toContain("status=pending");
    expect(href).toContain(
      "selected=content_report%3A96000000-0000-4000-8000-000000000001",
    );
    expect(push.mock.calls[0]?.[1]).toEqual({ scroll: false });
  });

  it("shows an empty state instead of an empty table", () => {
    render(<ReviewTable items={[]} nextCursor={null} selected={null} canSeeReporter canAccept />);
    expect(screen.getByText("No matching review items")).toBeInTheDocument();
  });

  it("closes the inspector on Escape and drops only the selection", async () => {
    push.mockReset();
    render(
      <ReviewTable
        items={[item()]}
        nextCursor={null}
        selected={detail()}
        canSeeReporter
        canAccept
      />,
    );
    expect(screen.getByText("Review details")).toBeInTheDocument();
    fireEvent.keyDown(screen.getByText("Review details"), { key: "Escape", code: "Escape" });
    await waitFor(() => expect(push).toHaveBeenCalledOnce());
    expect(push.mock.calls[0]?.[0] as string).not.toContain("selected=");
  });
});

function InspectorFocusHarness({ canSeeReporter }: Readonly<{ canSeeReporter: boolean }>) {
  const triggerRef = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);
  return (
    <>
      <button ref={triggerRef} type="button" onClick={() => setOpen(true)}>
        Open case
      </button>
      {open ? (
        <ReviewInspector
          item={detail()}
          canSeeReporter={canSeeReporter}
          canAccept
          triggerRef={triggerRef}
          onClose={() => setOpen(false)}
        />
      ) : null}
    </>
  );
}

describe("ReviewInspector", () => {
  it("restores focus to its trigger when closed", async () => {
    render(<InspectorFocusHarness canSeeReporter />);
    const trigger = screen.getByRole("button", { name: "Open case" });
    fireEvent.click(trigger);
    fireEvent.click(screen.getByRole("button", { name: "Close details" }));
    await waitFor(() => expect(trigger).toHaveFocus());
  });

  it("shows reporter identity to Administrators only", () => {
    const { unmount } = render(<InspectorFocusHarness canSeeReporter />);
    fireEvent.click(screen.getByRole("button", { name: "Open case" }));
    expect(screen.getByText("90000000-0000-4000-8000-000000000001")).toBeInTheDocument();
    unmount();

    render(<InspectorFocusHarness canSeeReporter={false} />);
    fireEvent.click(screen.getByRole("button", { name: "Open case" }));
    expect(
      screen.queryByText("90000000-0000-4000-8000-000000000001"),
    ).not.toBeInTheDocument();
  });
});
