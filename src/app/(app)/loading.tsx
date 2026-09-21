export default function Loading() {
  return <div className="space-y-6" role="status" aria-label="جاري التحميل"><div className="h-8 w-56 animate-pulse rounded-xl bg-slate-200" /><div className="h-5 w-full max-w-2xl animate-pulse rounded-lg bg-slate-200" /><div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">{Array.from({ length: 4 }).map((_, index) => <div key={index} className="h-36 animate-pulse rounded-2xl border border-[var(--border)] bg-white" />)}</div><span className="sr-only">جاري تحميل البيانات…</span></div>;
}
