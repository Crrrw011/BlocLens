import "server-only";

import { z } from "zod";

const staffMemberSchema = z.object({
  user_id: z.string().uuid(),
  username: z.string().min(1),
  role: z.string().min(1),
  active: z.boolean(),
  can_manage_administrators: z.boolean(),
  since: z.string().min(1),
});

const invitationSchema = z.object({
  id: z.string().uuid(),
  email: z.string().min(1),
  role: z.string().min(1),
  status: z.enum(["pending", "accepted", "revoked", "expired"]),
  expires_at: z.string().min(1),
  invited_by: z.string().uuid().nullable(),
  created_at: z.string().min(1),
});

export type StaffMember = z.infer<typeof staffMemberSchema>;
export type StaffInvitation = z.infer<typeof invitationSchema>;

export type StaffRoster = {
  staff: StaffMember[];
  invitations: StaffInvitation[];
};

export async function getStaffRoster(): Promise<
  | { ok: true; value: StaffRoster }
  | { ok: false; errorCode: string }
> {
  const { createServerClient } = await import("@/lib/supabase/server");
  const client = await createServerClient();
  const { data, error } = await client.rpc("admin_list_staff");
  if (error) return { ok: false, errorCode: "upstream" };
  const rows = z
    .array(z.object({ ok: z.boolean(), error_code: z.string().nullable(), payload: z.unknown().nullable() }))
    .safeParse(data ?? []);
  if (!rows.success || rows.data.length === 0) return { ok: false, errorCode: "upstream" };
  const row = rows.data[0]!;
  if (!row.ok || !row.payload) return { ok: false, errorCode: row.error_code ?? "upstream" };
  const parsed = z
    .object({ staff: z.array(staffMemberSchema), invitations: z.array(invitationSchema) })
    .safeParse(row.payload);
  if (!parsed.success) return { ok: false, errorCode: "upstream" };
  return { ok: true, value: parsed.data };
}
