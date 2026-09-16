import { describe, expect, it, vi } from "vitest";

import { logEvent, newTraceId, redactUnknown } from "./observability";

describe("redactUnknown", () => {
  it("masks credential keys wholesale", () => {
    expect(
      redactUnknown({
        password: "hunter2",
        authToken: "abc",
        nested: { cookie: "yum", safe: "keep" },
      }),
    ).toEqual({
      password: "[redacted]",
      authToken: "[redacted]",
      nested: { cookie: "[redacted]", safe: "keep" },
    });
  });

  it("masks JWT-shaped strings and embedded emails", () => {
    const jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c";
    expect(redactUnknown({ session: jwt })).toEqual({ session: "[redacted-token]" });
    expect(redactUnknown({ note: "contact admin@example.invalid today" })).toEqual({
      note: "contact [redacted-email] today",
    });
  });

  it("passes correlation IDs and plain values through", () => {
    const traceId = newTraceId();
    expect(redactUnknown({ trace_id: traceId, count: 3 })).toEqual({
      trace_id: traceId,
      count: 3,
    });
  });
});

describe("logEvent", () => {
  it("emits one redacted JSON line with stable correlation", () => {
    const spy = vi.spyOn(console, "log").mockImplementation(() => undefined);
    try {
      const traceId = newTraceId();
      const line = logEvent("review.decision", { password: "x", ok: true }, traceId);
      const parsed = JSON.parse(line) as Record<string, unknown>;
      expect(parsed.event).toBe("review.decision");
      expect(parsed.trace_id).toBe(traceId);
      expect(parsed.password).toBe("[redacted]");
      expect(parsed.ok).toBe(true);
      expect(spy).toHaveBeenCalledOnce();
    } finally {
      spy.mockRestore();
    }
  });
});
