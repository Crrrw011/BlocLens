"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

import type { ActionState } from "@/lib/auth/access";
import { createServerClient } from "@/lib/supabase/server";
import { messages } from "@/localization/messages";

const copy = messages.en.configuration;

export type ConfigurationActionState =
  | ActionState
  | { status: "error"; message: string; conflict: true };

const updateSchema = z.object({
  key: z.enum([
    "review.queue.order",
    "overview.default_range",
    "flags.moderation_notes",
    "copy.reason_templates",
  ]),
  // Typed per key below; transported as JSON text.
  value: z.string().min(1),
  reason: z.string().trim().min(1).max(2000),
  expectedVersion: z.coerce.number().int().min(1),
  idempotencyKey: z.string().uuid(),
});

type OutcomeRow = { ok: boolean; error_code: string | null };

function parseValue(
  key: z.infer<typeof updateSchema>["key"],
  raw: string,
): unknown | null {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  switch (key) {
    case "review.queue.order":
      return typeof parsed === "string" &&
        ["newest_first", "oldest_first", "severity_first"].includes(parsed)
        ? parsed
        : null;
    case "overview.default_range":
      return typeof parsed === "string" && ["7d", "30d", "90d"].includes(parsed)
        ? parsed
        : null;
    case "flags.moderation_notes":
      return typeof parsed === "boolean" ? parsed : null;
    case "copy.reason_templates":
      return Array.isArray(parsed) &&
        parsed.length >= 1 &&
        parsed.length <= 10 &&
        parsed.every(
          (template): template is string =>
            typeof template === "string" &&
            template.trim().length >= 1 &&
            template.length <= 200,
        )
        ? parsed
        : null;
  }
}

export async function updateConfiguration(
  _previous: ConfigurationActionState,
  formData: FormData,
): Promise<ConfigurationActionState> {
  const parsed = updateSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { status: "error", message: copy.invalidInput };
  }
  const value = parseValue(parsed.data.key, parsed.data.value);
  if (value === null) {
    return { status: "error", message: copy.invalidInput };
  }

  const supabase = await createServerClient();
  let data: unknown;
  try {
    const result = await supabase.rpc("admin_update_configuration", {
      config_key: parsed.data.key,
      config_value: value,
      reason: parsed.data.reason,
      expected_version: parsed.data.expectedVersion,
      idempotency_key: parsed.data.idempotencyKey,
    });
    if (result.error) return { status: "error", message: copy.unavailable };
    data = result.data;
  } catch {
    return { status: "error", message: copy.unavailable };
  }
  const row = (Array.isArray(data) ? data[0] : null) as OutcomeRow | null;
  if (!row) return { status: "error", message: copy.unavailable };
  if (!row.ok && row.error_code === "conflict") {
    return { status: "error", message: copy.conflictBody, conflict: true };
  }
  if (!row.ok) return { status: "error", message: copy.unavailable };

  revalidatePath("/configuration");
  return { status: "success" };
}
