export type PenaltyKind =
  | "publishing_restriction"
  | "timed_suspension"
  | "permanent_ban";

export type Restriction = {
  id: string;
  actionId: string | null;
  kind: PenaltyKind;
  reason: string;
  endsAt: string | null;
  createdAt: string;
};

export type ModerationHistoryEntry = {
  id: string;
  actionType: string;
  reason: string;
  createdAt: string;
};

export type UserSummary = {
  userId: string;
  username: string;
  memberSince: string;
  staffRole: string | null;
  activeRestrictions: Restriction[];
  recentActions: ModerationHistoryEntry[];
  contributionCounts: Record<string, number>;
};

export type PenaltyAction = {
  id: string;
  actionType: string;
  reason: string;
  createdAt: string;
};

export type PersonRow = {
  userId: string;
  username: string;
  memberSince: string;
  staffRole: string | null;
  restrictionKinds: PenaltyKind[];
};

export type PeoplePage = {
  items: PersonRow[];
  nextCursor: string | null;
};
