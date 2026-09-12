import Link from "next/link";
import { redirect } from "next/navigation";

import { requireStaff } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

import { SignInForm } from "../auth-forms";

export const dynamic = "force-dynamic";

export default async function SignInPage() {
  const supabase = await createServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) {
    await requireStaff();
    redirect("/overview");
  }

  return (
    <main className="grid min-h-dvh place-items-center bg-zinc-50 px-4 py-8 text-zinc-950 dark:bg-zinc-950 dark:text-zinc-50">
      <section className="w-full max-w-md rounded-lg border border-zinc-200 bg-white p-6 dark:border-zinc-800 dark:bg-zinc-900 sm:p-8">
        <h1 className="text-2xl font-semibold tracking-tight">
          {messages.en.auth.signIn.title}
        </h1>
        <div className="mt-6">
          <SignInForm />
        </div>
        <Link
          className="mt-5 inline-flex min-h-11 items-center text-sm font-medium text-blue-700 underline underline-offset-4 focus:outline-none focus:ring-2 focus:ring-blue-700 dark:text-blue-300"
          href="/forgot-password"
        >
          {messages.en.auth.signIn.forgotPassword}
        </Link>
      </section>
    </main>
  );
}
