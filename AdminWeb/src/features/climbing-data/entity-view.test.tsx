import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

import { EntityFilters } from "./entity-filters";
import { EntityTable } from "./entity-table";
import type { EntityDetail, EntityListItem } from "./types";

const { push } = vi.hoisted(() => ({ push: vi.fn() }));
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push }),
  usePathname: () => "/climbing-data/route",
  useSearchParams: () => new URLSearchParams("status=active"),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => {
    throw new Error("network clients are unavailable in view tests");
  },
}));

function item(overrides: Partial<EntityListItem> = {}): EntityListItem {
  return {
    kind: "route",
    id: "30000000-0000-4000-8000-000000000001",
    status: "active",
    title: "Blue",
    subtitle: "Urban Climb West End · River Slab",
    moderation: "visible",
    dependentCounts: { photos: 2 },
    updatedAt: "2026-09-15T00:00:00.000Z",
    createdAt: "2026-08-18T00:00:00.000Z",
    ...overrides,
  };
}

function detail(): EntityDetail {
  return {
    ...item(),
    details: { colour: "Blue", gym_grade: -1 },
    related: { photos: ["40000000-0000-4000-8000-000000000001"] },
    moderationHistory: [],
  };
}

describe("EntityFilters", () => {
  it("restores kind, status, gym, and search state", () => {
    render(
      <EntityFilters
        current={{ kind: "route", status: "hidden", gym: "gym-id", q: "Blue" }}
        gyms={[item({ kind: "gym", id: "gym-id", title: "Urban Climb West End" })]}
      />,
    );
    expect(screen.getByRole("link", { name: "Routes" })).toHaveAttribute("aria-current", "page");
    expect(screen.getByDisplayValue("Blue")).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "Urban Climb West End" })).toBeInTheDocument();
  });

  it("renders one tab per entity kind", () => {
    render(
      <EntityFilters current={{ kind: "gym", status: "all", gym: "", q: "" }} gyms={[]} />,
    );
    for (const label of ["Gyms", "Wall zones", "Routes", "Resets", "Photos", "Beta links", "Comments"]) {
      expect(screen.getByRole("link", { name: label })).toBeInTheDocument();
    }
  });
});

describe("EntityTable", () => {
  it("renders kind columns and selects a row into the inspector", () => {
    push.mockReset();
    render(<EntityTable kind="route" items={[item()]} nextCursor={null} selected={detail()} />);
    expect(screen.getByRole("columnheader", { name: "Moderation" })).toBeInTheDocument();
    expect(screen.getByRole("dialog", { name: "Record details" })).toBeVisible();
    expect(screen.getByRole("cell", { name: "Blue" })).toBeInTheDocument();
  });

  it("navigates selection without losing the active filters", () => {
    push.mockReset();
    render(<EntityTable kind="route" items={[item()]} nextCursor="cursor" selected={null} />);
    fireEvent.click(screen.getByRole("cell", { name: "Blue" }));
    expect(push).toHaveBeenCalledOnce();
    const href = push.mock.calls[0]?.[0] as string;
    expect(href).toContain("status=active");
    expect(href).toContain(`selected=${item().id}`);
  });

  it("shows an empty state instead of an empty table", () => {
    render(<EntityTable kind="gym" items={[]} nextCursor={null} selected={null} />);
    expect(screen.getByText("No matching records")).toBeInTheDocument();
  });
});
