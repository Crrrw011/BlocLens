import { redirect } from "next/navigation";

import { requireStaff } from "@/lib/auth/access";
import { en } from "@/lib/messages/en";
import { createServerClient } from "@/lib/supabase/server";
import { ConfigForm, type ConfigEntry } from "@/features/configuration/config-form";

const KEYS = [
  "review.queue.order",
  "overview.default_range",
  "flags.moderation_notes",
  "copy.reason_templates",
] as const;

const GROUP_TITLES: Record<string, string> = {
  "review.queue.order": en.configuration.groups.reviewQueue,
  "overview.default_range": en.configuration.groups.overview,
  "flags.moderation_notes": en.configuration.groups.flags,
  "copy.reason_templates": en.configuration.groups.templates,
};

export default async function ConfigurationPage() {
  const access = await requireStaff();
  if (access.role !== "admin") {
    redirect("/access-denied");
  }

  const supabase = await createServerClient();
  const { data, error } = await supabase
    .from("operational_configuration")
    .select("key,value,version")
    .in("key", [...KEYS]);
  if (error) {
    throw new Error("Configuration is unavailable");
  }
  const entries = new Map((data ?? []).map((row) => [row.key, row]));
  const missing = KEYS.filter((key) => !entries.has(key));
  if (missing.length > 0) {
    throw new Error(`Configuration is incomplete: ${missing.join(", ")}`);
  }

  return (
    <section className="portal-page" aria-label={en.configuration.title}>
      {KEYS.map((key) => {
        const row = entries.get(key) as { value: unknown; version: number };
        return (
          <section key={key} aria-labelledby={`config-group-${key}`}>
            <h3 id={`config-group-${key}`}>{GROUP_TITLES[key]}</h3>
            <ConfigForm
              entry={{ key, value: row.value, version: row.version }}
            />
          </section>
        );
      })}
      <section aria-labelledby="config-frozen">
        <h3 id="config-frozen">{en.configuration.groups.frozen}</h3>
        <ul>
          {en.configuration.frozen.map((rule) => (
            <li key={rule}>{rule}</li>
          ))}
        </ul>
      </section>
    </section>
  );
}
