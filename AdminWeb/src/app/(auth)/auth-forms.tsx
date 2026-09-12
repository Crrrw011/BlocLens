"use client";

import { useActionState, useEffect } from "react";

import { createBrowserClient } from "@/lib/supabase/browser";
import type { ActionState } from "@/lib/auth/access";
import { messages } from "@/localization/messages";

import { requestPasswordReset, updatePassword } from "./password-actions";
import { signIn } from "./sign-in/actions";

const initialState: ActionState = { status: "idle" };

function FormMessage({ state, successMessage }: { state: ActionState; successMessage?: string }) {
  if (state.status === "error") {
    return (
      <p className="text-sm text-red-700 dark:text-red-300" role="alert">
        {state.message}
      </p>
    );
  }

  if (state.status === "success" && successMessage) {
    return <p className="text-sm text-emerald-700 dark:text-emerald-300">{successMessage}</p>;
  }

  return null;
}

function FormField({
  autoComplete,
  label,
  name,
  placeholder,
  type,
}: {
  autoComplete: string;
  label: string;
  name: string;
  placeholder?: string;
  type: "email" | "password";
}) {
  return (
    <label className="grid gap-2 text-sm font-medium text-zinc-800 dark:text-zinc-100" htmlFor={name}>
      {label}
      <input
        autoComplete={autoComplete}
        className="min-h-11 rounded-md border border-zinc-300 bg-white px-3 text-base text-zinc-950 outline-none transition focus:border-blue-700 focus:ring-2 focus:ring-blue-200 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50 dark:focus:border-blue-400 dark:focus:ring-blue-950"
        id={name}
        name={name}
        placeholder={placeholder}
        required
        type={type}
      />
    </label>
  );
}

function SubmitButton({ isPending, label }: { isPending: boolean; label: string }) {
  return (
    <button
      aria-busy={isPending}
      className="min-h-12 rounded-md bg-blue-700 px-4 text-sm font-semibold text-white transition hover:bg-blue-800 active:translate-y-px motion-reduce:transition-none disabled:cursor-not-allowed disabled:opacity-60 dark:bg-blue-500 dark:hover:bg-blue-400"
      disabled={isPending}
      type="submit"
    >
      {label}
    </button>
  );
}

export function SignInForm() {
  const [state, formAction, isPending] = useActionState(
    async (_previousState: ActionState, formData: FormData) => signIn(formData),
    initialState,
  );

  return (
    <form action={formAction} className="grid gap-5" noValidate>
      <FormField
        autoComplete="email"
        label={messages.en.auth.signIn.emailLabel}
        name="email"
        placeholder={messages.en.auth.signIn.emailPlaceholder}
        type="email"
      />
      <FormField
        autoComplete="current-password"
        label={messages.en.auth.signIn.passwordLabel}
        name="password"
        type="password"
      />
      <FormMessage state={state} />
      <SubmitButton isPending={isPending} label={messages.en.auth.signIn.submit} />
    </form>
  );
}

export function ForgotPasswordForm() {
  const [state, formAction, isPending] = useActionState(
    async (_previousState: ActionState, formData: FormData) => requestPasswordReset(formData),
    initialState,
  );

  return (
    <form action={formAction} className="grid gap-5" noValidate>
      <FormField
        autoComplete="email"
        label={messages.en.auth.forgotPassword.emailLabel}
        name="email"
        placeholder={messages.en.auth.forgotPassword.emailPlaceholder}
        type="email"
      />
      <FormMessage state={state} successMessage={messages.en.auth.forgotPassword.success} />
      <SubmitButton isPending={isPending} label={messages.en.auth.forgotPassword.submit} />
    </form>
  );
}

export function UpdatePasswordForm() {
  const [state, formAction, isPending] = useActionState(
    async (_previousState: ActionState, formData: FormData) => updatePassword(formData),
    initialState,
  );

  useEffect(() => {
    createBrowserClient();
  }, []);

  return (
    <form action={formAction} className="grid gap-5" noValidate>
      <FormField
        autoComplete="new-password"
        label={messages.en.auth.updatePassword.passwordLabel}
        name="password"
        type="password"
      />
      <FormField
        autoComplete="new-password"
        label={messages.en.auth.updatePassword.passwordConfirmationLabel}
        name="passwordConfirmation"
        type="password"
      />
      <FormMessage state={state} />
      <SubmitButton isPending={isPending} label={messages.en.auth.updatePassword.submit} />
    </form>
  );
}
