import { messages } from "@/localization/messages";

export default function OverviewPage() {
  return (
    <section className="px-4 py-8">
      <h1 className="text-2xl font-semibold tracking-tight">{messages.en.auth.portal.title}</h1>
    </section>
  );
}
