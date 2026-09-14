"use client";

import * as DropdownMenu from "@radix-ui/react-dropdown-menu";
import {
  Bell,
  Mountains,
  Notebook,
  ShieldCheck,
  SignOut,
  SlidersHorizontal,
  SquaresFour,
  UsersThree,
} from "@phosphor-icons/react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useRef } from "react";

import type { StaffAccess } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";

const destinations = [
  { href: "/overview", label: en.shell.destinations.overview, icon: SquaresFour },
  { href: "/review", label: en.shell.destinations.review, icon: ShieldCheck },
  { href: "/climbing-data", label: en.shell.destinations.climbingData, icon: Mountains },
  {
    href: "/people",
    label: en.shell.destinations.peopleAccess,
    icon: UsersThree,
    administratorOnly: true,
  },
  { href: "/audit", label: en.shell.destinations.audit, icon: Notebook },
  {
    href: "/configuration",
    label: en.shell.destinations.configuration,
    icon: SlidersHorizontal,
    administratorOnly: true,
  },
] as const;

type IconRailProps = Readonly<{
  access: StaffAccess;
  signOutAction?: () => Promise<void>;
}>;

export function IconRail({ access, signOutAction }: IconRailProps) {
  const pathname = usePathname();
  const signOutFormRef = useRef<HTMLFormElement>(null);
  const roleLabel = en.shell.roles[access.role];
  const initials = roleLabel.slice(0, 2).toUpperCase();

  return (
    <nav className="icon-rail" aria-label={en.shell.primaryNavigation}>
      <Link className="icon-rail__brand focus-ring" href="/overview" aria-label={en.shell.brandLabel}>
        <span aria-hidden="true">B</span>
      </Link>

      <div className="icon-rail__destinations">
        {destinations
          .filter(
            (destination) =>
              !("administratorOnly" in destination) || access.role === "admin",
          )
          .map(({ href, label, icon: Icon }) => {
            const active = pathname === href || pathname.startsWith(`${href}/`);

            return (
              <Link
                key={href}
                className="icon-rail__control focus-ring"
                data-label={label}
                href={href}
                aria-current={active ? "page" : undefined}
                aria-label={label}
              >
                <Icon aria-hidden="true" size={20} weight={active ? "fill" : "regular"} />
              </Link>
            );
          })}
      </div>

      <div className="icon-rail__bottom" data-testid="rail-bottom-controls">
        <DropdownMenu.Root>
          <DropdownMenu.Trigger asChild>
            <button
              className="icon-rail__control focus-ring"
              data-label={en.shell.notifications}
              type="button"
              aria-label={en.shell.notifications}
            >
              <Bell aria-hidden="true" size={20} />
            </button>
          </DropdownMenu.Trigger>
          <DropdownMenu.Portal>
            <DropdownMenu.Content className="rail-menu" side="right" sideOffset={12}>
              <DropdownMenu.Label className="rail-menu__label">
                {en.shell.notifications}
              </DropdownMenu.Label>
              <div className="rail-menu__message">{en.shell.noNotifications}</div>
            </DropdownMenu.Content>
          </DropdownMenu.Portal>
        </DropdownMenu.Root>

        <DropdownMenu.Root>
          <DropdownMenu.Trigger asChild>
            <button
              className="icon-rail__avatar focus-ring"
              type="button"
              aria-label={en.shell.accountMenu}
            >
              <span aria-hidden="true">{initials}</span>
            </button>
          </DropdownMenu.Trigger>
          <DropdownMenu.Portal>
            <DropdownMenu.Content className="rail-menu" side="right" sideOffset={12}>
              <DropdownMenu.Label className="rail-menu__label">
                {en.shell.accountRole}
              </DropdownMenu.Label>
              <div className="rail-menu__message">{roleLabel}</div>
              {signOutAction ? (
                <form ref={signOutFormRef} action={signOutAction}>
                  <DropdownMenu.Item
                    asChild
                    onSelect={(event) => {
                      event.preventDefault();
                      signOutFormRef.current?.requestSubmit();
                    }}
                  >
                    <button className="rail-menu__action focus-ring" type="button">
                      <SignOut aria-hidden="true" size={18} />
                      {en.auth.portal.signOut}
                    </button>
                  </DropdownMenu.Item>
                </form>
              ) : null}
            </DropdownMenu.Content>
          </DropdownMenu.Portal>
        </DropdownMenu.Root>
      </div>
    </nav>
  );
}
