export type EntityKind =
  | "gym"
  | "wall_zone"
  | "route"
  | "reset"
  | "route_photo"
  | "beta_link"
  | "route_comment";

export type EntityListQuery = {
  kind: EntityKind;
  status: string;
  q: string;
  gymId: string | null;
  cursor: string | null;
  pageSize: number;
};

export type EntityListItem = {
  kind: EntityKind;
  id: string;
  status: string;
  title: string;
  subtitle: string | null;
  moderation: string | null;
  dependentCounts: Record<string, number>;
  updatedAt: string;
  createdAt: string;
};

export type ModerationHistoryEntry = {
  id: string;
  actionType: string;
  reason: string;
  createdAt: string;
};

export type EntityDetail = EntityListItem & {
  details: Record<string, unknown>;
  related: Record<string, unknown>;
  moderationHistory: ModerationHistoryEntry[];
};

export type DeletionImpact = {
  eligible: boolean;
  blockers: string[];
  dependentCounts: Record<string, number>;
  storagePaths: string[];
  alternative: "archive" | "merge" | "anonymise" | null;
};
