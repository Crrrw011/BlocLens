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
import { useEffect, useRef, useState } from "react";

import type { StaffAccess } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";

export type SidebarCounts = {
  reviewPending: number;
  pendingClaims: number;
  pendingInvites: number;
};

type Destination = {
  href: string;
  label: string;
  icon: typeof SquaresFour;
  administratorOnly?: boolean;
  tip: string;
};

const OPERATE: Destination[] = [
  { href: "/overview", label: en.shell.destinations.overview, icon: SquaresFour, tip: "Overview" },
  { href: "/review", label: en.shell.destinations.review, icon: ShieldCheck, tip: "Review queue" },
];

const MANAGE: Destination[] = [
  { href: "/climbing-data", label: en.shell.destinations.climbingData, icon: Mountains, tip: "Climbing data" },
  {
    href: "/people",
    label: en.shell.destinations.peopleAccess,
    icon: UsersThree,
    administratorOnly: true,
    tip: "People and access",
  },
];

const SYSTEM: Destination[] = [
  { href: "/audit", label: en.shell.destinations.audit, icon: Notebook, tip: "Audit log" },
  {
    href: "/configuration",
    label: en.shell.destinations.configuration,
    icon: SlidersHorizontal,
    administratorOnly: true,
    tip: "Configuration",
  },
];

const STORAGE_KEY = "bloclens-sidebar-collapsed";

function Group({
  name,
  destinations,
  pathname,
  counts,
}: Readonly<{
  name: string;
  destinations: Destination[];
  pathname: string;
  counts: SidebarCounts;
}>) {
  return (
    <>
      <div className="nav-group" aria-hidden="true">
        {name}
      </div>
      {destinations.map(({ href, label, icon: Icon, tip }) => {
        const active = pathname === href || pathname.startsWith(`${href}/`);
        return (
          <Link
            key={href}
            className="nav-item focus-ring"
            data-tip={tip}
            href={href}
            aria-current={active ? "page" : undefined}
          >
            <Icon aria-hidden="true" size={19} weight={active ? "fill" : "regular"} />
            <span className="lbl">{label}</span>
            {href === "/review" && counts.reviewPending > 0 ? (
              <span className="count">{counts.reviewPending}</span>
            ) : null}
            {href === "/people" && counts.pendingInvites > 0 ? (
              <span className="dot" aria-hidden="true" />
            ) : null}
          </Link>
        );
      })}
    </>
  );
}

type SidebarProps = Readonly<{
  access: StaffAccess;
  counts?: SidebarCounts;
  signOutAction?: () => Promise<void>;
}>;

export function Sidebar({ access, counts, signOutAction }: SidebarProps) {
  const pathname = usePathname();
  const signOutFormRef = useRef<HTMLFormElement>(null);
  const [collapsed, setCollapsed] = useState(false);
  const roleLabel = en.shell.roles[access.role];
  const initials = roleLabel.slice(0, 2).toUpperCase();
  const totals: SidebarCounts = counts ?? { reviewPending: 0, pendingClaims: 0, pendingInvites: 0 };

  useEffect(() => {
    try {
      setCollapsed(window.localStorage.getItem(STORAGE_KEY) === "1");
    } catch {
      // Private browsing: fall back to expanded.
    }
  }, []);

  const toggle = () => {
    setCollapsed((previous) => {
      const next = !previous;
      try {
        window.localStorage.setItem(STORAGE_KEY, next ? "1" : "0");
      } catch {
        // Ignore persistence failures.
      }
      return next;
    });
  };

  const visible = (group: Destination[]) =>
    group.filter((destination) => !destination.administratorOnly || access.role === "admin");

  return (
    <aside className={`sidebar${collapsed ? " collapsed" : ""}`}>
      <div className="sb-top">
        <button
          className="sb-toggle focus-ring"
          type="button"
          onClick={toggle}
          title={en.shell.toggleSidebar}
          aria-label={en.shell.toggleSidebar}
          aria-expanded={!collapsed}
        >
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
            <rect x="3" y="3" width="18" height="18" rx="2" />
            <line x1="9" y1="3" x2="9" y2="21" />
          </svg>
        </button>
        <div className="sb-title">
          {en.shell.brandTitle}
          <small>{en.shell.consoleSubtitle}</small>
        </div>
      </div>
      <button
        className="sb-search focus-ring"
        type="button"
        onClick={() => document.getElementById("operations-search")?.focus()}
      >
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
          <circle cx="11" cy="11" r="7" />
          <line x1="21" y1="21" x2="16.5" y2="16.5" />
        </svg>
        <span>{en.shell.navigate}</span>
        <kbd aria-hidden="true">⌘K</kbd>
      </button>
      <nav className="nav" aria-label={en.shell.primaryNavigation}>
        <Group name={en.shell.groups.operate} destinations={visible(OPERATE)} pathname={pathname} counts={totals} />
        <Group name={en.shell.groups.manage} destinations={visible(MANAGE)} pathname={pathname} counts={totals} />
        <Group name={en.shell.groups.system} destinations={visible(SYSTEM)} pathname={pathname} counts={totals} />
      </nav>
      <div className="sb-foot" data-testid="sidebar-footer">
        <div className="sb-foot__row">
          <DropdownMenu.Root>
            <DropdownMenu.Trigger asChild>
              <button
                className="icon-btn focus-ring"
                type="button"
                aria-label={en.shell.notifications}
              >
                <Bell aria-hidden="true" size={18} />
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
          <span className="lbl muted" style={{ fontSize: 12 }}>
            {en.shell.noNotifications}
          </span>
        </div>
        <div className="user-card">
          <div className="avatar" aria-hidden="true">
            {initials}
          </div>
          <div className="meta">
            <div className="n">{roleLabel}</div>
            <div className="r">{en.shell.staffMember}</div>
          </div>
          <DropdownMenu.Root>
            <DropdownMenu.Trigger asChild>
              <button
                className="icon-btn focus-ring"
                type="button"
                aria-label={en.shell.accountMenu}
              >
                <SignOut aria-hidden="true" size={18} />
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
      </div>
    </aside>
  );
}
