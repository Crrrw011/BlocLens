import Link from "next/link";

import { messages } from "@/localization/messages";

import { ForgotPasswordForm } from "../auth-forms";

export default function ForgotPasswordPage() {
  return (
    <main className="grid min-h-dvh place-items-center bg-zinc-50 px-4 py-8 text-zinc-950 dark:bg-zinc-950 dark:text-zinc-50">
      <section className="w-full max-w-md rounded-lg border border-zinc-200 bg-white p-6 dark:border-zinc-800 dark:bg-zinc-900 sm:p-8">
        <h1 className="text-2xl font-semibold tracking-tight">
          {messages.en.auth.forgotPassword.title}
        </h1>
        <p className="mt-2 text-sm leading-6 text-zinc-600 dark:text-zinc-300">
          {messages.en.auth.forgotPassword.body}
        </p>
        <div className="mt-6">
          <ForgotPasswordForm />
        </div>
        <Link
          className="mt-5 inline-flex min-h-11 items-center text-sm font-medium text-blue-700 underline underline-offset-4 focus:outline-none focus:ring-2 focus:ring-blue-700 dark:text-blue-300"
          href="/sign-in"
        >
          {messages.en.auth.forgotPassword.backToSignIn}
        </Link>
      </section>
    </main>
  );
}
