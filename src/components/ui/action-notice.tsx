export function ActionNotice({ saved, error }: { saved?: string; error?: string }) {
  if (saved) return <div role="status" className="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm font-bold text-emerald-800">تم حفظ التغيير بنجاح.</div>;
  if (error) return <div role="alert" className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-bold text-red-800">تعذر حفظ التغيير. راجع البيانات والصلاحيات ثم حاول مرة أخرى.</div>;
  return null;
}
