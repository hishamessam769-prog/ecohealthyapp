import { Suspense } from "react";

export function WorkspaceBoundary({ children }: { children: React.ReactNode }) {
  return <Suspense fallback={<div className="space-y-3"><div className="h-24 animate-pulse rounded-xl bg-[#e7eeea]"/><div className="h-96 animate-pulse rounded-xl bg-[#e7eeea]"/></div>}>{children}</Suspense>;
}
