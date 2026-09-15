import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { MetricsGrid } from "./metrics-grid";
import { PriorityTable } from "./priority-table";
import { QueueDistribution } from "./queue-distribution";
import { ReviewTrend } from "./review-trend";
import type { ReviewQueueItem } from "../review/types";

const counts = {
  pendingReports: 4,
  severeReports: 1,
  pendingCorrections: 2,
  duplicateRoutes: 1,
  pendingClaims: 0,
  hiddenContent: 3,
};

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

describe("MetricsGrid", () => {
  it("renders evidence-backed counts with deep links into filtered queues", () => {
    render(<MetricsGrid {...counts} />);
    expect(screen.getByRole("link", { name: /Pending reports: 4/ })).toHaveAttribute(
      "href",
      "/review?status=pending",
    );
    const severe = screen.getByRole("link", { name: /Severe reports: 1/ });
    expect(severe).toHaveAttribute("href", "/review?status=pending&severity=severe");
    expect(screen.getByRole("link", { name: /Possible duplicates: 1/ })).toHaveAttribute(
      "href",
      "/review?status=pending&kind=merge_suggestion",
    );
  });
});

describe("ReviewTrend", () => {
  it("announces totals textually and tabulates every point", () => {
    render(
      <ReviewTrend
        points={[
          { day: "2026-09-13", opened: 2, resolved: 1 },
          { day: "2026-09-14", opened: 0, resolved: 3 },
        ]}
      />,
    );
    expect(screen.getByText(/Opened: 2 total/)).toBeInTheDocument();
    expect(screen.getByRole("img", { name: /Review activity/ })).toBeInTheDocument();
    expect(screen.getByRole("rowheader", { name: "2026-09-13" })).toBeInTheDocument();
  });
});

describe("QueueDistribution", () => {
  it("shows every slice count as text", () => {
    render(
      <QueueDistribution
        slices={[
          { kind: "content_report", status: "open", count: 3 },
          { kind: "merge_suggestion", status: "proposed", count: 1 },
        ]}
      />,
    );
    expect(screen.getByText("3")).toBeInTheDocument();
    expect(
      screen.getByRole("img", { name: "merge_suggestion proposed: 1" }),
    ).toBeInTheDocument();
  });
});

describe("PriorityTable", () => {
  it("links each priority row into the selected review", () => {
    render(<PriorityTable items={[item()]} />);
    expect(
      screen.getByRole("link", { name: "harassment" }),
    ).toHaveAttribute(
      "href",
      "/review?status=pending&selected=content_report:96000000-0000-4000-8000-000000000001",
    );
    expect(screen.getByRole("columnheader", { name: "Waiting" })).toBeInTheDocument();
  });
});
