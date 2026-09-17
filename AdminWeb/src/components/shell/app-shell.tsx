import type { StaffAccess } from "@/lib/auth/access";

import { Sidebar, type SidebarCounts } from "./sidebar";
import { Topbar } from "./topbar";

type AppShellProps = Readonly<{
  access: StaffAccess;
  counts?: SidebarCounts;
  children: React.ReactNode;
  signOutAction?: () => Promise<void>;
}>;

export function AppShell({ access, counts, children, signOutAction }: AppShellProps) {
  return (
    <div className="app-shell">
      <Sidebar access={access} counts={counts} signOutAction={signOutAction} />
      <div className="app-shell__workspace">
        <Topbar />
        <div className="app-shell__content">{children}</div>
      </div>
    </div>
  );
}
