import { WarningCircle } from "@phosphor-icons/react/dist/ssr";

import { en } from "@/lib/messages/en";
import { Button } from "./button";

export function ErrorState({
  title = en.states.error.title,
  body = en.states.error.body,
  onRetry,
}: Readonly<{ title?: string; body?: string; onRetry: () => void }>) {
  return (
    <section className="state-view state-view--error" role="alert" aria-label={title}>
      <WarningCircle className="state-view__icon" aria-hidden="true" size={28} />
      <h2>{title}</h2>
      <p>{body}</p>
      <div className="state-view__action">
        <Button onClick={onRetry}>{en.states.error.retry}</Button>
      </div>
    </section>
  );
}
