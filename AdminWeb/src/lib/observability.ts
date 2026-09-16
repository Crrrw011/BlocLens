import { randomUUID } from "node:crypto";

const SENSITIVE_KEY = /(token|password|secret|cookie|authori[sz]ation|api[-_]?key|private[-_]?key)/i;
const JWT_SHAPE = /^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/;
const EMAIL_SHAPE = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;

export function newTraceId(): string {
  return randomUUID();
}

function redactString(value: string): string {
  if (JWT_SHAPE.test(value.trim())) return "[redacted-token]";
  return value.replace(EMAIL_SHAPE, "[redacted-email]");
}

/**
 * Recursively redacts secrets from structured log fields. Object keys that
 * name credentials are masked wholesale; JWT-shaped strings and embedded
 * emails are masked wherever they appear. Correlation IDs pass through:
 * they are random and carry no identity.
 */
export function redactUnknown(value: unknown): unknown {
  if (typeof value === "string") return redactString(value);
  if (Array.isArray(value)) return value.map(redactUnknown);
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, entry]) => [
        key,
        SENSITIVE_KEY.test(key) ? "[redacted]" : redactUnknown(entry),
      ]),
    );
  }
  return value;
}

export type LogFields = Record<string, unknown>;

/**
 * Single structured log line. Server actions and routes pass their trace ID
 * explicitly: Next.js RSC boundaries do not propagate AsyncLocalStorage, so
 * implicit context would silently drop correlation exactly when it matters.
 */
export function logEvent(
  event: string,
  fields: LogFields = {},
  traceId: string = newTraceId(),
): string {
  const line = JSON.stringify({
    timestamp: new Date().toISOString(),
    trace_id: traceId,
    event,
    ...((redactUnknown(fields) as LogFields) ?? {}),
  });
  console.log(line);
  return line;
}
