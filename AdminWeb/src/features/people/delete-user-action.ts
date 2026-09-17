"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import type { ActionState } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

const copy = messages.en.people.deletion;

export type DeleteUserActionState = ActionState;

type OutcomeRow = { ok: boolean; error_code: string | null };

const deleteSchema = z.object({
  userId: z.string().uuid(),
  username: z.string().trim().min(1).max(30),
  confirmedUsername: z.string().trim().min(1).max(30),
  reason: z.string().trim().min(1).max(1000),
  idempotencyKey: z.string().uuid(),
});

export async function deleteUser(
  _previous: DeleteUserActionState,
  formData: FormData,
): Promise<DeleteUserActionState> {
  const parsed = deleteSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success || parsed.data.username !== parsed.data.confirmedUsername) {
    return { status: "error", message: copy.invalidInput };
  }
  const supabase = await createServerClient();
  let data: unknown;
  try {
    const result = await supabase.rpc("admin_delete_user", {
      target_user_id: parsed.data.userId,
      reason: parsed.data.reason,
      idempotency_key: parsed.data.idempotencyKey,
    });
    data = result.data;
    if (result.error) return { status: "error", message: copy.unavailable };
  } catch {
    return { status: "error", message: copy.unavailable };
  }
  const row = (Array.isArray(data) ? data[0] : null) as OutcomeRow | null;
  if (!row) return { status: "error", message: copy.unavailable };
  if (!row.ok && row.error_code === "self_delete") {
    return { status: "error", message: copy.selfDelete };
  }
  if (!row.ok && row.error_code === "staff_protected") {
    return { status: "error", message: copy.staffProtected };
  }
  if (!row.ok) return { status: "error", message: copy.unavailable };
  revalidatePath("/people");
  redirect("/people?tab=members");
}
