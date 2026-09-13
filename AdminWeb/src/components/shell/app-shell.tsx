import type { StaffAccess } from "@/lib/auth/access";

import { IconRail } from "./icon-rail";
import { PageHeader } from "./page-header";

type AppShellProps = Readonly<{
  access: StaffAccess;
  children: React.ReactNode;
  signOutAction?: () => Promise<void>;
}>;

export function AppShell({ access, children, signOutAction }: AppShellProps) {
  return (
    <div className="app-shell">
      <IconRail access={access} signOutAction={signOutAction} />
      <main className="app-shell__workspace">
        <div className="app-shell__content">
          <PageHeader role={access.role} />
          {children}
        </div>
      </main>
    </div>
  );
}
