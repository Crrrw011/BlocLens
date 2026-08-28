// BlocLens account deletion endpoint.
//
// A signed-in user deletes their own account. The function never accepts a
// target user id from the client; it deletes only the caller identified by the
// verified JWT. Deleting the auth user triggers the database cascade that
// permanently removes private data and anonymises (SET NULL) public
// contributions. The service-role key lives only in this function's secret and
// is never shipped in the app.

import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function response(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return response({ error: "Method not allowed" }, 405);
  }

  // The user's own JWT identifies the caller. We do not trust any body field.
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) {
    return response({ error: "Missing authorization" }, 401);
  }

  const url = Deno.env.get("PROJECT_URL");
  const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY");
  if (!url || !serviceRoleKey) {
    return response({ error: "Server configuration error" }, 500);
  }

  const admin = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Resolve the caller from the token using the admin client.
  const { data: user, error: userError } = await admin.auth.getUser(token);
  if (userError || !user?.user) {
    return response({ error: "Unauthorized" }, 401);
  }
  const userId = user.user.id;

  // Delete the auth user. The DB cascade removes private rows and anonymises
  // public contributions via their `on delete set null` foreign keys.
  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    return response({ error: "Deletion failed" }, 500);
  }

  return response({ success: true }, 200);
});
