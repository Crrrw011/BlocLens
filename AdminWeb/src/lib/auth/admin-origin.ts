import { z } from "zod";

const configuredOriginSchema = z.string().trim().min(1);

export function getAdminOrigin(): string {
  const configuredOrigin = configuredOriginSchema.safeParse(process.env.ADMIN_ORIGIN);

  if (!configuredOrigin.success) {
    throw new Error("ADMIN_ORIGIN must be a configured HTTP(S) origin.");
  }

  let origin: URL;

  try {
    origin = new URL(configuredOrigin.data);
  } catch {
    throw new Error("ADMIN_ORIGIN must be a configured HTTP(S) origin.");
  }

  if (
    (origin.protocol !== "http:" && origin.protocol !== "https:") ||
    origin.username ||
    origin.password ||
    origin.pathname !== "/" ||
    origin.search ||
    origin.hash
  ) {
    throw new Error("ADMIN_ORIGIN must be a configured HTTP(S) origin.");
  }

  return origin.origin;
}
