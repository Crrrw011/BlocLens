type StatusTone = "neutral" | "accent" | "success" | "warning" | "danger" | "archived";

export function StatusBadge({
  children,
  tone = "neutral",
}: Readonly<{ children: React.ReactNode; tone?: StatusTone }>) {
  return <span className={`status-badge status-badge--${tone}`}>{children}</span>;
}
