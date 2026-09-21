import Link from "next/link";
import { Leaf, LockKeyhole, ShieldCheck } from "lucide-react";
import { loginAction } from "@/app/actions/auth";
import { isPreviewMode } from "@/lib/supabase/config";

export const metadata = { title: "تسجيل الدخول" };

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;
  const preview = isPreviewMode();
  const messages: Record<string, string> = {
    configuration: "لم يتم ربط Supabase بعد. أضف متغيرات البيئة ثم أعد المحاولة.",
    validation: "تحقق من البريد الإلكتروني وكلمة المرور.",
    credentials: "بيانات الدخول غير صحيحة أو الحساب غير نشط.",
  };

  return (
    <main className="grid min-h-screen lg:grid-cols-[1.1fr_0.9fr]">
      <section className="relative hidden overflow-hidden bg-[var(--primary)] p-12 text-white lg:flex lg:flex-col lg:justify-between">
        <div className="absolute -left-32 -top-32 size-96 rounded-full bg-[#b5d77d]/15" />
        <div className="relative flex items-center gap-3">
          <span className="grid size-11 place-items-center rounded-2xl bg-white/12"><Leaf size={24} /></span>
          <div><strong className="block text-lg">Eco Healthy</strong><span className="text-sm text-white/65">Enterprise workspace</span></div>
        </div>
        <div className="relative max-w-xl">
          <p className="mb-5 text-sm font-bold text-[#cce7a4]">نظام واحد، حقيقة مالية واحدة</p>
          <h1 className="text-5xl font-black leading-[1.25]">إدارة يومية أبسط، وقرارات يمكن تتبعها.</h1>
          <p className="mt-6 text-lg leading-8 text-white/70">مساحة تشغيل موحدة للمبيعات والمالية والاشتراكات والمشروعات، مبنية بصلاحيات دقيقة وأثر تدقيق كامل.</p>
        </div>
        <div className="relative flex gap-8 text-sm text-white/65">
          <span className="flex items-center gap-2"><ShieldCheck size={18} />صلاحيات دقيقة</span>
          <span className="flex items-center gap-2"><LockKeyhole size={18} />بيانات محمية</span>
        </div>
      </section>

      <section className="flex items-center justify-center p-5 sm:p-10">
        <div className="w-full max-w-md">
          <div className="mb-9 flex items-center gap-3 lg:hidden">
            <span className="grid size-11 place-items-center rounded-2xl bg-[var(--primary)] text-white"><Leaf size={23} /></span>
            <strong>Eco Healthy ERP</strong>
          </div>
          <p className="text-sm font-extrabold text-[var(--primary)]">مرحبًا بعودتك</p>
          <h2 className="mt-2 text-3xl font-black">تسجيل الدخول</h2>
          <p className="mt-3 text-sm leading-6 text-[var(--text-muted)]">استخدم حساب العمل المصرح به للوصول إلى مساحة Eco Healthy.</p>

          {error ? <div role="alert" className="mt-6 rounded-xl border border-red-200 bg-red-50 p-3 text-sm font-semibold text-red-700">{messages[error] || "تعذر تسجيل الدخول."}</div> : null}
          {preview ? <div className="mt-6 rounded-xl border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">وضع المعاينة مفعل محليًا فقط. لا يستخدم بيانات مالية أو إنتاجية.</div> : null}

          <form action={loginAction} className="mt-7 space-y-5">
            <label className="block text-sm font-bold">البريد الإلكتروني <span className="text-red-600">*</span>
              <input name="email" type="email" required autoComplete="email" className="mt-2 h-12 w-full rounded-xl border border-[var(--border)] bg-white px-4 outline-none transition focus:border-[var(--primary)]" placeholder="name@ecohealthy.com" />
            </label>
            <label className="block text-sm font-bold">كلمة المرور <span className="text-red-600">*</span>
              <input name="password" type="password" required minLength={8} autoComplete="current-password" className="mt-2 h-12 w-full rounded-xl border border-[var(--border)] bg-white px-4 outline-none transition focus:border-[var(--primary)]" placeholder="••••••••" />
            </label>
            <button type="submit" className="h-12 w-full rounded-xl bg-[var(--primary)] font-extrabold text-white transition hover:bg-[var(--primary-strong)]">دخول آمن</button>
          </form>

          {preview ? <Link href="/dashboard" className="mt-3 flex h-12 w-full items-center justify-center rounded-xl border border-[var(--border)] bg-white text-sm font-extrabold hover:bg-[var(--surface-muted)]">فتح المعاينة بدون حساب</Link> : null}
          <p className="mt-8 text-center text-xs leading-5 text-[var(--text-muted)]">لا تشارك بيانات الدخول. تُسجل محاولات الوصول والأفعال الإدارية الحساسة.</p>
        </div>
      </section>
    </main>
  );
}
