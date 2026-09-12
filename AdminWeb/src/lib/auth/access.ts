import { redirect } from "next/navigation";

import { createServerClient } from "@/lib/supabase/server";

export type StaffRole = "admin" | "moderator";

export type StaffAccess = {
  userId: string;
  role: StaffRole;
  canManageAdministrators: boolean;
};

export type ActionState =
  | { status: "idle" }
  | { status: "error"; message: string; fieldErrors?: Record<string, string[]> }
  | { status: "success" };

type CurrentStaffAccess = {
  user_id: string;
  role: string;
  can_manage_administrators: boolean;
  is_active: boolean;
};

function isStaffRole(role: string): role is StaffRole {
  return role === "admin" || role === "moderator";
}

export async function requireStaff(): Promise<StaffAccess> {
  const supabase = await createServerClient();
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    redirect("/sign-in");
  }

  const { data, error } = await supabase
    .rpc("current_staff_access")
    .maybeSingle<CurrentStaffAccess>();

  if (
    error ||
    !data ||
    !data.is_active ||
    data.user_id !== user.id ||
    !isStaffRole(data.role)
  ) {
    redirect("/access-denied");
  }

  return {
    userId: user.id,
    role: data.role,
    canManageAdministrators:
      data.role === "admin" && data.can_manage_administrators,
  };
}
