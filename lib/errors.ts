import { randomUUID } from "node:crypto";

export type ErrorCode = "UNAUTHENTICATED" | "FORBIDDEN" | "NOT_FOUND" | "VALIDATION" | "CONFLICT" | "RATE_LIMITED" | "CONFIG" | "INTERNAL";

export class AppError extends Error {
  constructor(public readonly code: ErrorCode, message: string, public readonly status = 400, public readonly details?: unknown) {
    super(message);
    this.name = "AppError";
  }
}

export function errorId() {
  return `ECO-${new Date().toISOString().slice(0, 10).replaceAll("-", "")}-${randomUUID().slice(0, 8).toUpperCase()}`;
}

export function normalizeError(cause: unknown) {
  if (cause instanceof AppError) return cause;
  if (cause instanceof Error && cause.message.startsWith("ECO_CONFIG_INVALID")) return new AppError("CONFIG", "إعدادات الخادم غير مكتملة.", 503);
  return new AppError("INTERNAL", "تعذر تنفيذ العملية.", 500);
}
