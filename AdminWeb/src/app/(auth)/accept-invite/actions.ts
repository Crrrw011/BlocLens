"use server";
import type { ActionState } from "@/lib/auth/access";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

export async function acceptInvitation(formData: FormData): Promise<ActionState> {
  const copy = messages.en.auth.acceptInvite;
  const parsed = z.object({
    tokenDigest: z.string().regex(/^[a-f0-9]{64}$/),
    password: z.string().min(12).max(128),
    passwordConfirmation: z.string(),
  }).safeParse(Object.fromEntries(formData));
  if (!parsed.success) return { status: "error", message: copy.invalidInput };
  if (parsed.data.password !== parsed.data.passwordConfirmation) {
    return { status: "error", message: messages.en.auth.updatePassword.confirmationMismatch };
  }
  const supabase = await createServerClient();
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user?.email_confirmed_at) return { status: "error", message: copy.unavailable };
  // Auth credentials and Postgres role activation are separate operations.
  // Never activate access until the password update is confirmed; SQL then
  // atomically revalidates issuer authority and consumes the invitation.
  const { error: passwordError } = await supabase.auth.updateUser({ password: parsed.data.password });
  if (passwordError) return { status: "error", message: copy.passwordError };
  const { data, error: acceptanceError } = await supabase.rpc("accept_staff_invitation", {
    token_digest: `\\x${parsed.data.tokenDigest}`,
  });
  if (acceptanceError || !data?.[0]?.invitation_accepted) {
    return { status: "error", message: copy.unavailable };
  }
  redirect("/overview");
}
