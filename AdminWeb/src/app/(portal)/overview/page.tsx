import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";

export default async function OverviewPage() {
  await requireStaff();

  return <section className="portal-page" aria-label={en.shell.overviewWorkspace} />;
}
