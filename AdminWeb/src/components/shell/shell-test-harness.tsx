"use client";

import { useRef, useState } from "react";

import { en } from "@/lib/messages/en";

import { Button } from "../ui/button";
import { DataTable, type DataTableColumn } from "../ui/data-table";
import { Dialog, DialogContent, DialogTrigger } from "../ui/dialog";
import { StatusBadge } from "../ui/status-badge";
import { Inspector } from "./inspector";

type ReviewSample = {
  id: string;
  item: string;
  area: string;
  status: string;
  source: string;
};

const reviewSamples: ReviewSample[] = [
  {
    id: "route-report",
    item: en.shell.testHarness.rows.routeReport,
    area: en.shell.testHarness.rows.southWall,
    status: en.shell.testHarness.rows.needsReview,
    source: en.shell.testHarness.rows.climberReport,
  },
  {
    id: "route-correction",
    item: en.shell.testHarness.rows.routeCorrection,
    area: en.shell.testHarness.rows.cave,
    status: en.shell.testHarness.rows.pending,
    source: en.shell.testHarness.rows.staffReview,
  },
];

const columns: DataTableColumn<ReviewSample>[] = [
  {
    id: "item",
    header: en.shell.testHarness.columns.item,
    cell: ({ row }) => row.original.item,
  },
  {
    id: "area",
    header: en.shell.testHarness.columns.area,
    cell: ({ row }) => row.original.area,
  },
  {
    id: "status",
    header: en.shell.testHarness.columns.status,
    cell: ({ row }) => <StatusBadge tone="warning">{row.original.status}</StatusBadge>,
  },
  {
    id: "source",
    header: en.shell.testHarness.columns.source,
    cell: ({ row }) => row.original.source,
  },
];

export function ShellTestHarness() {
  const inspectorTriggerRef = useRef<HTMLButtonElement>(null);
  const [inspectorOpen, setInspectorOpen] = useState(false);

  return (
    <section className="portal-page shell-harness" aria-labelledby="shell-harness-title">
      <header className="shell-harness__header">
        <div>
          <h2 id="shell-harness-title">{en.shell.testHarness.title}</h2>
          <p>{en.shell.testHarness.description}</p>
        </div>
        <Button
          ref={inspectorTriggerRef}
          data-testid="primary-button"
          onClick={() => setInspectorOpen(true)}
        >
          {en.shell.testHarness.openInspector}
        </Button>
      </header>

      <div className="shell-harness__actions" aria-label={en.shell.testHarness.actionsLabel}>
        <Button variant="secondary" data-testid="secondary-button">
          {en.shell.testHarness.secondaryAction}
        </Button>
        <Button variant="destructive" data-testid="destructive-button">
          {en.shell.testHarness.destructiveAction}
        </Button>
        <Button variant="compact">{en.shell.testHarness.compactAction}</Button>
        <Button variant="secondary" className="shell-harness__batch-action">
          {en.shell.testHarness.batchAction}
        </Button>
      </div>

      <DataTable
        caption={en.shell.testHarness.tableCaption}
        columns={columns}
        data={reviewSamples}
        getRowId={(row) => row.id}
        onRowActivate={() => setInspectorOpen(true)}
      />

      <Inspector
        open={inspectorOpen}
        title={en.shell.testHarness.inspectorTitle}
        triggerRef={inspectorTriggerRef}
        onOpenChange={setInspectorOpen}
        footer={
          <Button variant="secondary" onClick={() => setInspectorOpen(false)}>
            {en.shell.testHarness.closeInspector}
          </Button>
        }
      >
        <p>{en.shell.testHarness.inspectorBody}</p>
        <Dialog>
          <DialogTrigger asChild>
            <Button variant="secondary">{en.shell.testHarness.openDecision}</Button>
          </DialogTrigger>
          <DialogContent
            title={en.shell.testHarness.decisionTitle}
            description={en.shell.testHarness.decisionDescription}
          >
            <Button>{en.shell.testHarness.confirmDecision}</Button>
          </DialogContent>
        </Dialog>
      </Inspector>
    </section>
  );
}
