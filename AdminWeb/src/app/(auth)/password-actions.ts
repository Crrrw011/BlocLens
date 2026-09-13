"use server";

import { redirect } from "next/navigation";
import { z } from "zod";

import type { ActionState } from "@/lib/auth/access";
import { getAdminOrigin } from "@/lib/auth/admin-origin";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

const emailSchema = z.string().trim().email();
const passwordSchema = z
  .object({
    password: z.string().min(12),
    passwordConfirmation: z.string(),
  })
  .refine(({ password, passwordConfirmation }) => password === passwordConfirmation, {
    message: messages.en.auth.updatePassword.confirmationMismatch,
    path: ["passwordConfirmation"],
  });

export async function requestPasswordReset(formData: FormData): Promise<ActionState> {
  const email = emailSchema.safeParse(formData.get("email"));

  if (!email.success) {
    return { status: "success" };
  }

  const supabase = await createServerClient();
  const redirectTo = new URL("/update-password", getAdminOrigin()).toString();

  await supabase.auth.resetPasswordForEmail(email.data, {
    redirectTo,
  });

  return { status: "success" };
}

export async function updatePassword(formData: FormData): Promise<ActionState> {
  const passwords = passwordSchema.safeParse({
    password: formData.get("password"),
    passwordConfirmation: formData.get("passwordConfirmation"),
  });

  if (!passwords.success) {
    const message = passwords.error.issues[0]?.message;

    return {
      status: "error",
      message:
        message === messages.en.auth.updatePassword.confirmationMismatch
          ? message
          : messages.en.auth.updatePassword.invalidPassword,
    };
  }

  const supabase = await createServerClient();
  const { error } = await supabase.auth.updateUser({ password: passwords.data.password });

  if (error) {
    return {
      status: "error",
      message: messages.en.auth.updatePassword.requestNewLink,
    };
  }

  redirect("/overview");
}
