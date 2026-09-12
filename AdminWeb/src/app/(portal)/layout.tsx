import { requireStaff } from "@/lib/auth/access";
import { messages } from "@/localization/messages";

import { signOut } from "./sign-out-action";

export default async function PortalLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  await requireStaff();

  return (
    <main className="min-h-dvh bg-zinc-50 text-zinc-950 dark:bg-zinc-950 dark:text-zinc-50">
      <header className="flex min-h-16 items-center justify-end border-b border-zinc-200 px-4 dark:border-zinc-800">
        <form action={signOut}>
          <button
            className="min-h-11 rounded-md px-3 text-sm font-medium text-blue-700 underline underline-offset-4 focus:outline-none focus:ring-2 focus:ring-blue-700 dark:text-blue-300"
            type="submit"
          >
            {messages.en.auth.portal.signOut}
          </button>
        </form>
      </header>
      {children}
    </main>
  );
}
