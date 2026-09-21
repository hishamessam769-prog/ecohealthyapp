import { redirect } from "next/navigation";
import { Building2, KeyRound, ShieldCheck } from "lucide-react";
import { firstTimeSetupAction } from "@/app/actions/setup";
import { createAdminClient } from "@/lib/supabase/admin";
import { hasSupabaseBrowserConfig } from "@/lib/supabase/config";

export const metadata = { title: "إعداد النظام لأول مرة" };

const field = "mt-2 h-12 w-full rounded-xl border border-[var(--border)] bg-white px-4 outline-none focus:border-[var(--primary)]";

export default async function SetupPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const query = await searchParams;
  const configured = hasSupabaseBrowserConfig() && Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY && process.env.SETUP_SECRET);
  if (configured) {
    const admin = createAdminClient();
    const { data } = await admin.from("system_installations").select("id").limit(1);
    if (data?.length) redirect("/login?setup=completed");
  }
  const messages: Record<string, string> = {
    validation: "راجع البيانات وSetup Secret. كلمة المرور يجب ألا تقل عن 12 حرفًا.",
    account: "تعذر إنشاء حساب Admin. تحقق من أن البريد غير مستخدم.",
    claim: "لم يكتمل الإعداد وتم التراجع عن إنشاء الحساب بأمان.",
  };

  return <main className="min-h-screen bg-[var(--primary)] p-4 sm:p-8">
    <div className="mx-auto grid min-h-[calc(100vh-4rem)] max-w-6xl overflow-hidden rounded-3xl bg-white shadow-2xl lg:grid-cols-[0.8fr_1.2fr]">
      <aside className="flex flex-col justify-between bg-[#123d30] p-8 text-white sm:p-12">
        <div className="flex items-center gap-3"><span className="grid size-12 place-items-center rounded-2xl bg-white/10"><Building2 /></span><div><strong>Eco Healthy ERP</strong><small className="block text-white/60">First-time setup</small></div></div>
        <div><p className="text-sm font-bold text-[#b5d77d]">خطوة واحدة آمنة</p><h1 className="mt-3 text-4xl font-black leading-tight">أنشئ الشركة وأول مسؤول.</h1><p className="mt-5 leading-7 text-white/65">بعد النجاح تتعطل هذه الصفحة تلقائيًا، ولا يمكن استخدامها لإنشاء مسؤول ثانٍ.</p></div>
        <div className="flex items-center gap-2 text-sm text-white/65"><ShieldCheck size={18} />لا تُحفظ كلمة المرور داخل SQL أوGit</div>
      </aside>
      <section className="p-6 sm:p-12">
        <h2 className="text-2xl font-black">إعداد المؤسسة</h2><p className="mt-2 text-sm text-[var(--text-muted)]">نفذ Master SQL أولًا، ثم أكمل هذه البيانات مرة واحدة.</p>
        {!configured ? <div className="mt-6 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm font-semibold text-amber-900">أضف Supabase URL وAnon Key وService Role Key وSETUP_SECRET إلى بيئة Vercel أولًا.</div> : null}
        {query.error ? <div className="mt-6 rounded-xl border border-red-200 bg-red-50 p-4 text-sm font-semibold text-red-800">{messages[query.error] || "تعذر إكمال الإعداد."}</div> : null}
        <form action={firstTimeSetupAction} className="mt-7 grid gap-5 sm:grid-cols-2">
          <label className="text-sm font-bold">اسم الشركة *<input name="companyName" required className={field} placeholder="Eco Healthy" /></label>
          <label className="text-sm font-bold">رمز الشركة *<input name="companyCode" required pattern="[A-Za-z0-9_]+" className={field} placeholder="ECO" /></label>
          <label className="text-sm font-bold">اسم المسؤول *<input name="adminName" required className={field} /></label>
          <label className="text-sm font-bold">بريد المسؤول *<input name="adminEmail" type="email" required className={field} /></label>
          <label className="text-sm font-bold">كلمة المرور *<input name="adminPassword" type="password" minLength={12} required autoComplete="new-password" className={field} /></label>
          <label className="text-sm font-bold">Setup Secret *<span className="relative block"><KeyRound className="absolute end-4 top-6 text-[var(--text-muted)]" size={18} /><input name="setupSecret" type="password" minLength={12} required className={`${field} pe-11`} /></span></label>
          <button disabled={!configured} className="h-12 rounded-xl bg-[var(--primary)] font-extrabold text-white disabled:opacity-50 sm:col-span-2">إنشاء أول Admin وبدء النظام</button>
        </form>
      </section>
    </div>
  </main>;
}
