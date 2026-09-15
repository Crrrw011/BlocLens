import { z } from "zod";
import { getAdminOrigin } from "@/lib/auth/admin-origin";
import { inviteStaff } from "@/lib/staff/invitations";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const inputSchema = z.object({
  email: z.string().trim().email().max(320),
  role: z.enum(["admin", "moderator"]),
  reason: z.string().trim().min(1).max(2000),
}).strict();
const headers = { "Cache-Control": "no-store" };

export async function POST(request: Request): Promise<Response> {
  if (request.headers.get("origin") !== getAdminOrigin()) {
    return Response.json({ status: "denied" }, { status: 403, headers });
  }
  const parsed = inputSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return Response.json({ status: "invalid" }, { status: 400, headers });
  try {
    return Response.json(await inviteStaff(parsed.data), { status: 202, headers });
  } catch {
    return Response.json({ status: "denied" }, { status: 403, headers });
  }
}
