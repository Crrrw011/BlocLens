import type { Metadata } from "next";
import { messages } from "@/localization/messages";
import { AcceptInvitationForm } from "./accept-invitation-form";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { referrer: "no-referrer", robots: { index: false, follow: false } };

export default function AcceptInvitationPage() {
  const copy = messages.en.auth.acceptInvite;
  return (
    <main className="invitation-page">
      <section className="invitation-panel" aria-labelledby="invitation-title">
        <h1 id="invitation-title">{copy.title}</h1>
        <p className="invitation-description">{copy.body}</p>
        <AcceptInvitationForm />
      </section>
    </main>
  );
}
