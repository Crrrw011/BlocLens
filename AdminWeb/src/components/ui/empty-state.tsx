import { Tray } from "@phosphor-icons/react/dist/ssr";

import { en } from "@/lib/messages/en";

export function EmptyState({
  title = en.states.empty.title,
  body = en.states.empty.body,
  action,
}: Readonly<{ title?: string; body?: string; action: React.ReactNode }>) {
  return (
    <section className="state-view" aria-label={title}>
      <Tray className="state-view__icon" aria-hidden="true" size={28} />
      <h2>{title}</h2>
      <p>{body}</p>
      <div className="state-view__action">{action}</div>
    </section>
  );
}
