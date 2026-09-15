"use client";

import { useActionState, useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import type { ActionState } from "@/lib/auth/access";
import { createBrowserClient } from "@supabase/ssr";
import { env } from "@/lib/env";
import { messages } from "@/localization/messages";
import { acceptInvitation } from "./actions";

export function AcceptInvitationForm() {
  const [tokenDigest, setTokenDigest] = useState("");
  const [sessionState, setSessionState] = useState<"loading" | "ready" | "invalid">("loading");
  const [state, action, pending] = useActionState(
    async (_previous: ActionState, formData: FormData) => acceptInvitation(formData),
    { status: "idle" } as ActionState,
  );
  const copy = messages.en.auth.acceptInvite;

  useEffect(() => {
    let mounted = true;
    const token = new URL(window.location.href).searchParams.get("token");
    // Admin Auth invitations return an implicit session, not a PKCE code.
    // Disable automatic URL detection and explicitly establish cookie storage.
    const callback = new URLSearchParams(window.location.hash.slice(1));
    const accessToken = callback.get("access_token");
    const refreshToken = callback.get("refresh_token");
    const supabase = createBrowserClient(env.NEXT_PUBLIC_SUPABASE_URL, env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, {
      isSingleton: false,
      auth: { detectSessionInUrl: false },
    });
    window.history.replaceState(null, "", "/accept-invite");
    async function prepare() {
      // Keep only a digest in transient form state, never credentials in props.
      const { data, error } = accessToken && refreshToken
        ? await supabase.auth.setSession({ access_token: accessToken, refresh_token: refreshToken })
        : await supabase.auth.getSession();
      if (!token || !/^[A-Za-z0-9_-]{43}$/.test(token) || error || !data.session) {
        if (mounted) setSessionState("invalid");
        return;
      }
      const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
      if (mounted) {
        setTokenDigest(Array.from(new Uint8Array(bytes), (value) => value.toString(16).padStart(2, "0")).join(""));
        setSessionState("ready");
      }
    }
    void prepare().catch(() => {
      window.history.replaceState(null, "", "/accept-invite");
      if (mounted) setSessionState("invalid");
    });
    return () => { mounted = false; };
  }, []);

  return (
    <form action={action} className="invitation-form">
      <input name="tokenDigest" type="hidden" value={tokenDigest} />
      <label htmlFor="password">
        {messages.en.auth.updatePassword.passwordLabel}
        <input id="password" name="password" type="password" autoComplete="new-password" minLength={12} maxLength={128} required aria-describedby="invitation-feedback" />
      </label>
      <label htmlFor="passwordConfirmation">
        {messages.en.auth.updatePassword.passwordConfirmationLabel}
        <input id="passwordConfirmation" name="passwordConfirmation" type="password" autoComplete="new-password" required aria-describedby="invitation-feedback" />
      </label>
      <div id="invitation-feedback" aria-live="polite">
        {sessionState === "loading" && <p role="status">{copy.preparing}</p>}
        {sessionState === "invalid" && <p className="invitation-error" role="alert">{copy.unavailable}</p>}
        {state.status === "error" && <p className="invitation-error" role="alert">{state.message}</p>}
      </div>
      <Button type="submit" disabled={pending || sessionState !== "ready"} aria-busy={pending}>{copy.submit}</Button>
    </form>
  );
}
