"use client";

import Link from "next/link";

import type { DataTableColumn } from "@/components/ui/data-table";
import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import type { EntityKind, EntityListItem } from "./types";

const copy = en.climbingData.table.columns;

function statusTone(status: string): "neutral" | "accent" | "success" | "warning" | "danger" | "archived" {
  if (status === "active" || status === "visible" || status === "confirmed") return "success";
  if (status === "hidden" || status === "pending" || status === "open") return "warning";
  if (status === "deleted") return "danger";
  if (status === "archived") return "archived";
  return "neutral";
}

function updatedAgo(iso: string): string {
  const days = Math.max(0, Math.floor((Date.now() - Date.parse(iso)) / 86400000));
  if (days === 0) return "today";
  if (days === 1) return "yesterday";
  return `${days}d ago`;
}

function baseColumns(link: (row: EntityListItem) => string): DataTableColumn<EntityListItem>[] {
  return [
    {
      id: "title",
      header: copy.title,
      cell: ({ row }) => <Link href={link(row.original)}>{row.original.title}</Link>,
    },
    {
      id: "detail",
      header: copy.detail,
      cell: ({ row }) => row.original.subtitle ?? "—",
    },
    {
      id: "status",
      header: copy.status,
      cell: ({ row }) => (
        <StatusBadge tone={statusTone(row.original.status)}>{row.original.status}</StatusBadge>
      ),
    },
    {
      id: "updated",
      header: copy.updated,
      cell: ({ row }) => updatedAgo(row.original.updatedAt),
    },
  ];
}

function moderationColumn(): DataTableColumn<EntityListItem> {
  return {
    id: "moderation",
    header: copy.moderation,
    cell: ({ row }) => row.original.moderation ?? "—",
  };
}

export const entityColumns: Record<EntityKind, DataTableColumn<EntityListItem>[]> = {
  gym: baseColumns((row) => `/climbing-data/gym/${row.id}`),
  wall_zone: baseColumns((row) => `/climbing-data/wall_zone/${row.id}`),
  route: [...baseColumns((row) => `/climbing-data/route/${row.id}`), moderationColumn()],
  reset: baseColumns((row) => `/climbing-data/reset/${row.id}`),
  route_photo: [...baseColumns((row) => `/climbing-data/route_photo/${row.id}`), moderationColumn()],
  beta_link: [...baseColumns((row) => `/climbing-data/beta_link/${row.id}`), moderationColumn()],
  route_comment: [...baseColumns((row) => `/climbing-data/route_comment/${row.id}`), moderationColumn()],
};
