import { requireStaff } from "@/lib/auth/access";
import { AppShell } from "@/components/shell/app-shell";
import type { SidebarCounts } from "@/components/shell/sidebar";

import { signOut } from "./sign-out-action";

async function loadCounts(): Promise<SidebarCounts | undefined> {
  try {
    const [{ getOverviewMetrics }, { getStaffRoster }] = await Promise.all([
      import("@/features/overview/repository"),
      import("@/features/staff/repository"),
    ]);
    const [metricsResult, rosterResult] = await Promise.all([
      getOverviewMetrics("30d"),
      getStaffRoster(),
    ]);
    if (!metricsResult.ok) return undefined;
    const metrics = metricsResult.value;
    return {
      reviewPending:
        metrics.pendingReports + metrics.pendingCorrections + metrics.duplicateRoutes,
      pendingClaims: metrics.pendingClaims,
      pendingInvites:
        rosterResult.ok
          ? rosterResult.value.invitations.filter((invitation) => invitation.status === "pending")
              .length
          : 0,
    };
  } catch {
    return undefined;
  }
}

export default async function PortalLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const access = await requireStaff();
  const counts = await loadCounts();

  return (
    <AppShell access={access} counts={counts} signOutAction={signOut}>
      {children}
    </AppShell>
  );
}
