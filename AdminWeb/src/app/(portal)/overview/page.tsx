import { requireStaff } from "@/lib/auth/access";
import { messages } from "@/localization/messages";

export default async function OverviewPage() {
  await requireStaff();

  return (
    <section className="px-4 py-8">
      <h1 className="text-2xl font-semibold tracking-tight">{messages.en.auth.portal.title}</h1>
    </section>
  );
}
