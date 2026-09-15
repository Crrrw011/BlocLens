import { StatusBadge } from "@/components/ui/status-badge";
import { en } from "@/lib/messages/en";
import { PenaltyDialog, ReversePenaltyButton } from "./penalty-dialog";
import type { UserSummary } from "./types";

const copy = en.people.detail;

export function UserDetail({
  summary,
  canPenalise,
}: Readonly<{ summary: UserSummary; canPenalise: boolean }>) {
  return (
    <div>
      <section aria-labelledby="user-identifiers">
        <h3 id="user-identifiers">{summary.username}</h3>
        <dl>
          <div className="inspector-detail">
            <dt>{copy.memberSince}</dt>
            <dd>{summary.memberSince.slice(0, 10)}</dd>
          </div>
          <div className="inspector-detail">
            <dt>{copy.staffRole}</dt>
            <dd>{summary.staffRole ?? "—"}</dd>
          </div>
        </dl>
      </section>

      <section aria-labelledby="user-restrictions">
        <h3 id="user-restrictions">{copy.restrictions}</h3>
        {summary.activeRestrictions.length === 0 ? (
          <p>{copy.noRestrictions}</p>
        ) : (
          <ul>
            {summary.activeRestrictions.map((restriction) => (
              <li key={restriction.id}>
                <StatusBadge tone="danger">{restriction.kind}</StatusBadge>{" "}
                {restriction.reason}
                {canPenalise && restriction.actionId ? (
                  <ReversePenaltyButton actionId={restriction.actionId} />
                ) : null}
              </li>
            ))}
          </ul>
        )}
        {canPenalise ? <PenaltyDialog userId={summary.userId} username={summary.username} /> : null}
      </section>

      <section aria-labelledby="user-contributions">
        <h3 id="user-contributions">{copy.contributions}</h3>
        <ul>
          {Object.entries(summary.contributionCounts).map(([table, count]) => (
            <li key={table}>
              {table}: {count}
            </li>
          ))}
        </ul>
      </section>

      <section aria-labelledby="user-history">
        <h3 id="user-history">{copy.history}</h3>
        {summary.recentActions.length === 0 ? (
          <p>{copy.noHistory}</p>
        ) : (
          <ul>
            {summary.recentActions.map((entry) => (
              <li key={entry.id}>
                {entry.actionType} · {entry.createdAt} · {entry.reason}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
