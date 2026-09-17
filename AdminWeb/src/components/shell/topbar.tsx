"use client";

import { MagnifyingGlass } from "@phosphor-icons/react";
import { usePathname } from "next/navigation";
import { useEffect, useRef } from "react";

import { en } from "@/lib/messages/en";

const crumbs: Record<string, string> = {
  "/overview": en.shell.destinations.overview,
  "/review": en.shell.destinations.review,
  "/climbing-data": en.shell.destinations.climbingData,
  "/staff": en.people.staff.title,
  "/people": en.shell.destinations.peopleAccess,
  "/audit": en.shell.destinations.audit,
  "/configuration": en.shell.destinations.configuration,
};

export function Topbar() {
  const pathname = usePathname();
  const searchRef = useRef<HTMLInputElement>(null);
  const crumb =
    Object.entries(crumbs).find(([path]) => pathname === path || pathname.startsWith(`${path}/`))?.[1] ??
    en.metadata.operationsTitle;

  useEffect(() => {
    function focusSearch(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        const target =
          document.getElementById("operations-search") ?? searchRef.current;
        target?.focus();
      }
    }

    document.addEventListener("keydown", focusSearch);
    return () => document.removeEventListener("keydown", focusSearch);
  }, []);

  return (
    <div className="topbar">
      <div className="crumbs">
        BlocLens / <b>{crumb}</b>
      </div>
      <div className="global-search">
        <MagnifyingGlass aria-hidden="true" size={15} />
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
      </div>
    </div>
  );
}
