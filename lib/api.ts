import { NextResponse } from "next/server";
import { errorId, normalizeError } from "@/lib/errors";
import { logEvent } from "@/lib/logging";

export function ok<T>(data: T, status = 200) {
  return NextResponse.json({ ok: true, data, timestamp: new Date().toISOString() }, { status });
}

export function apiError(cause: unknown, context: Record<string, unknown> = {}) {
  const id = errorId();
  const error = normalizeError(cause);
  logEvent("error", "api_error", { errorId: id, code: error.code, status: error.status, ...context });
  return NextResponse.json({ ok: false, error: { id, code: error.code, message: error.message, details: error.details } }, { status: error.status });
}

export async function parseJson(request: Request) {
  try { return await request.json() as unknown; }
  catch { throw new Error("INVALID_JSON"); }
}
