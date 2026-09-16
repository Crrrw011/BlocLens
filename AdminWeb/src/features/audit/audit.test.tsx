import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { GET as cronGET } from "../../app/api/cron/audit-ip-retention/route";
import { GET as exportGET } from "../../app/api/audit/export/route";
import {
  MAX_EXPORT_DAYS,
  auditCsvHeader,
  auditRowToCsv,
  escapeCsvCell,
  type AuditEvent,
} from "./export";
import { listAuditEvents } from "./repository";

const { rpc, requireStaff, createAdminClient, cronCreateClient } = vi.hoisted(() => ({
  rpc: vi.fn(),
  requireStaff: vi.fn(),
  createAdminClient: vi.fn(),
  cronCreateClient: vi.fn(),
}));
vi.mock("@/lib/supabase/server", () => ({
  createServerClient: async () => ({ rpc }),
}));
vi.mock("@/lib/auth/access", () => ({ requireStaff }));
vi.mock("@supabase/supabase-js", () => ({ createClient: cronCreateClient }));
vi.mock("@/lib/env", () => ({
  env: {
    NEXT_PUBLIC_SUPABASE_URL: "http://127.0.0.1:54321",
    NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "test-key",
  },
}));
void createAdminClient;

function event(overrides: Partial<AuditEvent> = {}): AuditEvent {
  return {
    id: "94000000-0000-4000-8000-000000000001",
    actorId: "90000000-0000-4000-8000-000000000007",
    actionKey: "review.decision",
    targetType: "content_report",
    targetId: "96000000-0000-4000-8000-000000000001",
    reason: "Spam pattern confirmed",
    outcome: "succeeded",
    beforeSummary: { status: "open" },
    afterSummary: { status: "dismissed" },
    createdAt: "2026-09-15T00:00:00.000Z",
    ...overrides,
  };
}

describe("escapeCsvCell", () => {
  it("neutralises spreadsheet formulas and quotes safely", () => {
    expect(escapeCsvCell("=cmd|'/c calc'!A0")).toBe("'=cmd|'/c calc'!A0");
    expect(escapeCsvCell("+123")).toBe("'+123");
    expect(escapeCsvCell("-2+3")).toBe("'-2+3");
    expect(escapeCsvCell("@mention")).toBe("'@mention");
    expect(escapeCsvCell("\tindented")).toBe("'\tindented");
    expect(escapeCsvCell('say "hi", ok')).toBe('"say ""hi"", ok"');
    expect(escapeCsvCell("plain")).toBe("plain");
  });
});

describe("auditRowToCsv", () => {
  it("emits explicit columns in order with no IP field", () => {
    const line = auditRowToCsv(event());
    expect(line.split(",")[0]).toBe("2026-09-15T00:00:00.000Z");
    expect(auditCsvHeader().split(",")).toHaveLength(9);
    expect(auditCsvHeader()).not.toContain("ip");
    expect(line).not.toContain("203.0.113");
  });

  it("escapes hostile reason text", () => {
    const line = auditRowToCsv(event({ reason: "=HYPERLINK(\"http://evil.invalid\")" }));
    expect(line).toContain("'=HYPERLINK");
  });
});

function auditRow(overrides: Record<string, unknown> = {}) {
  return {
    id: "94000000-0000-4000-8000-000000000001",
    actor_id: "90000000-0000-4000-8000-000000000007",
    action_key: "review.decision",
    target_type: "content_report",
    target_id: "96000000-0000-4000-8000-000000000001",
    reason: "Spam pattern confirmed",
    outcome: "succeeded",
    before_summary: { status: "open" },
    after_summary: { status: "dismissed" },
    created_at: "2026-09-15T00:00:00.000Z",
    ...overrides,
  };
}

describe("listAuditEvents", () => {
  it("rejects reversed windows and injection-shaped filters without calling the database", async () => {
    rpc.mockReset();
    const reversed = await listAuditEvents(
      { from: "2026-09-15T00:00:00.000Z", to: "2026-09-14T00:00:00.000Z" },
      rpc,
    );
    expect(reversed.ok).toBe(false);
    const injected = await listAuditEvents(
      {
        from: "2026-09-14T00:00:00.000Z",
        to: "2026-09-15T00:00:00.000Z",
        action: "x'; drop table;",
      },
      rpc,
    );
    expect(injected.ok).toBe(false);
    expect(rpc).not.toHaveBeenCalled();
  });

  it("maps rows and trims the lookahead into a cursor", async () => {
    rpc.mockReset().mockResolvedValue({ data: [auditRow()], error: null });
    const result = await listAuditEvents(
      { from: "2026-09-14T00:00:00.000Z", to: "2026-09-15T00:00:00.000Z" },
      rpc,
    );
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.items).toHaveLength(1);
      expect(result.value.nextCursor).toBeNull();
    }
    expect(rpc).toHaveBeenCalledWith("admin_list_audit", {
      actor_filter: null,
      action_filter: null,
      target_filter: null,
      outcome_filter: null,
      range_start: "2026-09-14T00:00:00.000Z",
      range_end: "2026-09-15T00:00:00.000Z",
      page_after: null,
      page_size: 20,
    });
  });
});

describe("audit export route", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    requireStaff.mockResolvedValue({ userId: "admin", role: "admin", canManageAdministrators: true });
  });

  it("denies unauthenticated callers", async () => {
    requireStaff.mockRejectedValue(new Error("redirect:/sign-in"));
    const response = await exportGET(new Request("http://127.0.0.1:3000/api/audit/export"));
    expect(response.status).toBe(403);
  });

  it("rejects ranges beyond the maximum window", async () => {
    const response = await exportGET(
      new Request(
        `http://127.0.0.1:3000/api/audit/export?from=2026-01-01T00:00:00.000Z&to=2026-12-31T00:00:00.000Z`,
      ),
    );
    expect(response.status).toBe(400);
    expect(rpc).not.toHaveBeenCalled();
    expect(MAX_EXPORT_DAYS).toBe(90);
  });

  it("streams BOM-prefixed CSV with escaped cells", async () => {
    rpc.mockResolvedValue({
      data: [auditRow({ reason: "=HYPERLINK(\"http://evil.invalid\")" })],
      error: null,
    });
    const response = await exportGET(
      new Request(
        "http://127.0.0.1:3000/api/audit/export?from=2026-09-14T00:00:00.000Z&to=2026-09-15T00:00:00.000Z",
      ),
    );
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("text/csv");
    // TextDecoder strips BOM on .text(); verify the raw leading bytes instead.
    const bytes = new Uint8Array(await response.clone().arrayBuffer()).slice(0, 3);
    expect([...bytes]).toEqual([0xef, 0xbb, 0xbf]);
    const text = await response.text();
    expect(text.startsWith("created_at")).toBe(true);
    expect(text).toContain("'=HYPERLINK");
  });
});

describe("audit IP retention cron route", () => {
  const SECRET = "test-cron-secret";
  const SERVICE_KEY = "test-service-key";
  let savedCron: string | undefined;
  let savedService: string | undefined;

  beforeEach(() => {
    vi.clearAllMocks();
    savedCron = process.env.CRON_SECRET;
    savedService = process.env.SUPABASE_SECRET_KEY;
    process.env.CRON_SECRET = SECRET;
    process.env.SUPABASE_SECRET_KEY = SERVICE_KEY;
    cronCreateClient.mockReturnValue({ rpc: vi.fn().mockResolvedValue({ data: 3, error: null }) });
  });

  afterEach(() => {
    if (savedCron === undefined) {
      delete process.env.CRON_SECRET;
    } else {
      process.env.CRON_SECRET = savedCron;
    }
    if (savedService === undefined) {
      delete process.env.SUPABASE_SECRET_KEY;
    } else {
      process.env.SUPABASE_SECRET_KEY = savedService;
    }
  });

  function request(authorization?: string) {
    return new Request("http://127.0.0.1:3000/api/cron/audit-ip-retention", {
      headers: authorization ? { authorization } : {},
    });
  }

  it("rejects missing and invalid secrets", async () => {
    delete process.env.CRON_SECRET;
    expect((await cronGET(request(`Bearer ${SECRET}`))).status).toBe(500);
    process.env.CRON_SECRET = SECRET;
    expect((await cronGET(request())).status).toBe(401);
    expect((await cronGET(request("Bearer wrong"))).status).toBe(401);
  });

  it("runs retention exactly once per authorised call", async () => {
    const response = await cronGET(request(`Bearer ${SECRET}`));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: "ok", redacted: 3 });
    const rpcMock = cronCreateClient.mock.results[0]?.value.rpc as ReturnType<typeof vi.fn>;
    expect(rpcMock).toHaveBeenCalledWith("run_audit_ip_retention");
  });

  it("reports provider failures without claiming success", async () => {
    cronCreateClient.mockReturnValue({
      rpc: vi.fn().mockResolvedValue({ data: null, error: { message: "down" } }),
    });
    expect((await cronGET(request(`Bearer ${SECRET}`))).status).toBe(500);
  });
});
