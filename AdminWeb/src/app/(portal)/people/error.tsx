"use client";

import { ErrorState } from "@/components/ui/error-state";

export default function PeopleError({
  reset,
}: Readonly<{ error: Error & { digest?: string }; reset: () => void }>) {
  return <ErrorState onRetry={reset} />;
}
