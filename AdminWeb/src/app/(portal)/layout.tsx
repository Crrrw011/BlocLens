import { requireStaff } from "@/lib/auth/access";
import { AppShell } from "@/components/shell/app-shell";

import { signOut } from "./sign-out-action";

export default async function PortalLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const access = await requireStaff();

  return (
    <AppShell access={access} signOutAction={signOut}>
      {children}
    </AppShell>
  );
}
