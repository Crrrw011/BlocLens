import { messages } from "@/localization/messages";

import { UpdatePasswordForm } from "../auth-forms";

export default function UpdatePasswordPage() {
  return (
    <main className="grid min-h-dvh place-items-center bg-zinc-50 px-4 py-8 text-zinc-950 dark:bg-zinc-950 dark:text-zinc-50">
      <section className="w-full max-w-md rounded-lg border border-zinc-200 bg-white p-6 dark:border-zinc-800 dark:bg-zinc-900 sm:p-8">
        <h1 className="text-2xl font-semibold tracking-tight">
          {messages.en.auth.updatePassword.title}
        </h1>
        <p className="mt-2 text-sm leading-6 text-zinc-600 dark:text-zinc-300">
          {messages.en.auth.updatePassword.body}
        </p>
        <div className="mt-6">
          <UpdatePasswordForm />
        </div>
      </section>
    </main>
  );
}
