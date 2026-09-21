import Link from "next/link";
import { ShieldAlert } from "lucide-react";

export default function NotFound() {
  return <main className="grid min-h-screen place-items-center p-6"><div className="max-w-md text-center"><span className="mx-auto grid size-16 place-items-center rounded-2xl bg-amber-50 text-amber-700"><ShieldAlert size={30} /></span><h1 className="mt-5 text-2xl font-black">الصفحة غير متاحة</h1><p className="mt-3 text-sm leading-6 text-[var(--text-muted)]">قد لا تملك الصلاحية المطلوبة أو أن المسار غير موجود. لا يُعرض محتوى الوحدات خارج نطاق المستخدم.</p><Link href="/dashboard" className="mt-6 inline-flex h-11 items-center rounded-xl bg-[var(--primary)] px-5 text-sm font-bold text-white">العودة للرئيسية</Link></div></main>;
}
