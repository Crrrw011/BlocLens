"use server";

import { redirect } from "next/navigation";
import { z } from "zod";

import type { ActionState } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

const credentialsSchema = z.object({
  email: z.string().trim().email(),
  password: z.string().min(1),
});

const invalidCredentials: ActionState = {
  status: "error",
  message: messages.en.auth.signIn.invalidCredentials,
};

export async function signIn(formData: FormData): Promise<ActionState> {
  const credentials = credentialsSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });

  if (!credentials.success) {
    return invalidCredentials;
  }

  const supabase = await createServerClient();
  const { error } = await supabase.auth.signInWithPassword(credentials.data);

  if (error) {
    return invalidCredentials;
  }

  redirect("/overview");
}
