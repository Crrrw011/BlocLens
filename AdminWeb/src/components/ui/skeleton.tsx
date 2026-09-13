import { en } from "@/lib/messages/en";

type SkeletonProps = Readonly<{
  className?: string;
  label?: string;
}>;

export function Skeleton({ className = "", label = en.states.loading }: SkeletonProps) {
  return (
    <span
      className={`skeleton ${className}`.trim()}
      role="status"
      aria-label={label}
    />
  );
}
