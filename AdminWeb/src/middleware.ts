import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

import { updateSession } from "@/lib/supabase/middleware";

function isPortalPath(pathname: string) {
  return pathname === "/overview" || pathname.startsWith("/overview/");
}

function hasSessionCookie(request: NextRequest) {
  return request.cookies
    .getAll()
    .some(({ name }) => name.startsWith("sb-") && name.includes("-auth-token"));
}

const NO_STORE_PATHS = [
  "/overview",
  "/review",
  "/climbing-data",
  "/people",
  "/staff",
  "/audit",
  "/configuration",
  "/sign-in",
  "/forgot-password",
  "/update-password",
  "/accept-invite",
  "/access-denied",
];

export async function middleware(request: NextRequest) {
  const response = await updateSession(request);

  // Authenticated views and credential flows are never cached anywhere.
  if (NO_STORE_PATHS.some((path) => request.nextUrl.pathname.startsWith(path))) {
    response.headers.set("Cache-Control", "no-store");
  }

  if (!isPortalPath(request.nextUrl.pathname) || hasSessionCookie(request)) {
    return response;
  }

  // Note: Next.js normalises loopback request hosts to localhost when
  // building absolute redirect URLs. Unauthenticated bounces may therefore
  // land on localhost:3000/sign-in; that origin stays self-consistent
  // through relative in-app navigation, and ADMIN_ORIGIN alignment is
  // documented in the environment runbook. Do not hand-roll absolute
  // URLs here (NextResponse requires them; plain relative Responses crash
  // the middleware adapter).
  const signInURL = request.nextUrl.clone();
  signInURL.pathname = "/sign-in";
  signInURL.search = "";
  return NextResponse.redirect(signInURL);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
