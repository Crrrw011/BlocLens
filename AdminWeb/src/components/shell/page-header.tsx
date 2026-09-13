"use client";

import { MagnifyingGlass } from "@phosphor-icons/react";
import { usePathname } from "next/navigation";
import { useEffect, useRef } from "react";

import type { StaffRole } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";

const pageTitles: Record<string, string> = {
  "/overview": en.shell.destinations.overview,
  "/review": en.shell.destinations.review,
  "/climbing-data": en.shell.destinations.climbingData,
  "/people": en.shell.destinations.peopleAccess,
  "/audit": en.shell.destinations.audit,
  "/configuration": en.shell.destinations.configuration,
};

export function PageHeader({ role }: Readonly<{ role: StaffRole }>) {
  const pathname = usePathname();
  const searchRef = useRef<HTMLInputElement>(null);
  const pageTitle =
    Object.entries(pageTitles).find(([path]) => pathname === path || pathname.startsWith(`${path}/`))?.[1] ??
    en.metadata.operationsTitle;

  useEffect(() => {
    function focusSearch(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        searchRef.current?.focus();
      }
    }

    document.addEventListener("keydown", focusSearch);
    return () => document.removeEventListener("keydown", focusSearch);
  }, []);

  return (
    <header className="page-header">
      <div className="page-header__title">
        <h1>{pageTitle}</h1>
        <span>{en.shell.roles[role]}</span>
      </div>
      <form className="page-header__search" role="search" onSubmit={(event) => event.preventDefault()}>
        <MagnifyingGlass aria-hidden="true" size={17} />
        <label className="sr-only" htmlFor="operations-search">
          {en.shell.search.label}
        </label>
        <input
          ref={searchRef}
          className="focus-ring"
          id="operations-search"
          type="search"
          placeholder={en.shell.search.placeholder}
        />
        <kbd aria-label={en.shell.search.shortcut}>⌘ K</kbd>
      </form>
    </header>
  );
}
