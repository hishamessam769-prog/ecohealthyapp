import Link from "next/link";

export default function ForbiddenPage() {
  return <main className="grid min-h-screen place-items-center bg-[#f4f7f5] p-6"><div className="max-w-md rounded-xl border bg-white p-8 text-center shadow-sm"><div className="mx-auto flex size-14 items-center justify-center rounded-full bg-red-50 text-2xl text-red-700">×</div><h1 className="mt-4 text-2xl font-black">لا توجد صلاحية</h1><p className="mt-2 text-[#66736b]">الحساب مسجل، لكن الدور الحالي لا يسمح بعرض هذه الصفحة.</p><Link href="/" className="mt-6 inline-flex min-h-11 items-center rounded-lg bg-[#16794a] px-5 font-bold text-white">العودة للرئيسية</Link></div></main>;
}
