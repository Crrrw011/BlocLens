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

export async function middleware(request: NextRequest) {
  const response = await updateSession(request);

  if (!isPortalPath(request.nextUrl.pathname) || hasSessionCookie(request)) {
    return response;
  }

  const signInURL = request.nextUrl.clone();
  signInURL.pathname = "/sign-in";
  signInURL.search = "";
  return NextResponse.redirect(signInURL);
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
