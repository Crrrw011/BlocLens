import { messages } from "@/localization/messages";

import { signOut } from "../(portal)/sign-out-action";

export default function AccessDeniedPage() {
  return (
    <main className="grid min-h-dvh place-items-center bg-zinc-50 px-4 py-8 text-zinc-950 dark:bg-zinc-950 dark:text-zinc-50">
      <section className="w-full max-w-md rounded-lg border border-zinc-200 bg-white p-6 dark:border-zinc-800 dark:bg-zinc-900 sm:p-8">
        <h1 className="text-2xl font-semibold tracking-tight">
          {messages.en.auth.accessDenied.title}
        </h1>
        <p className="mt-2 text-sm leading-6 text-zinc-600 dark:text-zinc-300">
          {messages.en.auth.accessDenied.body}
        </p>
        <form action={signOut} className="mt-6">
          <button
            className="min-h-12 rounded-md bg-blue-700 px-4 text-sm font-semibold text-white transition hover:bg-blue-800 active:translate-y-px motion-reduce:transition-none dark:bg-blue-500 dark:hover:bg-blue-400"
            type="submit"
          >
            {messages.en.auth.accessDenied.signOut}
          </button>
        </form>
      </section>
    </main>
  );
}
