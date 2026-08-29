export function logEvent(level: "info" | "warn" | "error", event: string, data: Record<string, unknown>) {
  const safe = Object.fromEntries(Object.entries(data).filter(([key]) => !/password|token|proof|phone|address/i.test(key)));
  const line = JSON.stringify({ timestamp: new Date().toISOString(), level, event, ...safe });
  if (level === "error") console.error(line);
  else if (level === "warn") console.warn(line);
  else console.info(line);
}
