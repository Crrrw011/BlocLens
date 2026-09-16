import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { updateConfiguration } from "./actions";
import { ConfigForm } from "./config-form";

const { rpc, revalidatePath } = vi.hoisted(() => ({
  rpc: vi.fn(),
  revalidatePath: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => ({ rpc }),
}));
vi.mock("next/cache", () => ({ revalidatePath }));

function form(
  overrides: Partial<{ key: string; value: string; reason: string; expectedVersion: string }> = {},
) {
  const data = new FormData();
  data.set("key", "review.queue.order");
  data.set("value", '"severity_first"');
  data.set("reason", "Moderators asked for severe-first triage");
  data.set("expectedVersion", "1");
  data.set("idempotencyKey", "99000000-0000-4000-8000-000000000001");
  for (const [key, value] of Object.entries(overrides)) {
    if (value !== undefined) data.set(key, value);
  }
  return data;
}

describe("updateConfiguration", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    rpc.mockResolvedValue({ data: [{ ok: true, error_code: null }], error: null });
  });

  it("sends typed values and revalidates configuration", async () => {
    const result = await updateConfiguration({ status: "idle" }, form());
    expect(result).toEqual({ status: "success" });
    expect(rpc).toHaveBeenCalledWith("admin_update_configuration", {
      config_key: "review.queue.order",
      config_value: "severity_first",
      reason: "Moderators asked for severe-first triage",
      expected_version: 1,
      idempotency_key: "99000000-0000-4000-8000-000000000001",
    });
    expect(revalidatePath).toHaveBeenCalledWith("/configuration");
  });

  it("rejects mistyped values and unknown keys before any database call", async () => {
    for (const bad of [
      { key: "grades.community_formula", value: '"median"' },
      { key: "review.queue.order", value: '"sideways"' },
      { key: "flags.moderation_notes", value: '"yes"' },
      { key: "copy.reason_templates", value: "[]" },
      { reason: "" },
    ]) {
      const result = await updateConfiguration({ status: "idle" }, form(bad));
      expect(result.status).toBe("error");
    }
    expect(rpc).not.toHaveBeenCalled();
  });

  it("maps stale versions to a conflict state", async () => {
    rpc.mockResolvedValue({ data: [{ ok: false, error_code: "conflict" }], error: null });
    const result = await updateConfiguration({ status: "idle" }, form());
    expect(result.status).toBe("error");
    if (result.status === "error") expect("conflict" in result).toBe(true);
  });
});

describe("ConfigForm", () => {
  it("renders the current value and frozen rules stay outside the form", () => {
    render(
      <ConfigForm entry={{ key: "review.queue.order", value: "newest_first", version: 1 }} />,
    );
    expect(screen.getByLabelText("Default queue order")).toBeInTheDocument();
    expect(screen.getByLabelText("Reason")).toBeInTheDocument();
  });

  it("serialises template lines as a JSON array", () => {
    const { container } = render(
      <ConfigForm entry={{ key: "copy.reason_templates", value: ["One", "Two"], version: 3 }} />,
    );
    const box = screen.getByLabelText("Templates (one per line)");
    expect(box).toHaveValue("One\nTwo");
    fireEvent.change(box, { target: { value: "One\n\nThree" } });
    const hidden = container.querySelector('input[name="value"]') as HTMLInputElement;
    expect(JSON.parse(hidden.value)).toEqual(["One", "Three"]);
  });
});
