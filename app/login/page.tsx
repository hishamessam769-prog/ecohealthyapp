import { LoginForm } from "@/components/login-form";

export default function LoginPage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[#f4f7f5] px-4 py-10">
      <section className="w-full max-w-md border border-[#dce5df] bg-white p-6 sm:p-8">
        <div className="mb-8">
          <div className="mb-5 flex h-12 w-16 items-center justify-center bg-[#16794a] text-sm font-bold tracking-wide text-white">
            ECO
          </div>
          <h1 className="text-2xl font-bold text-[#17211b]">ECO Healthy ERP</h1>
          <p className="mt-2 text-sm leading-6 text-[#66736b]">
            سجّل الدخول بحساب الموظف للوصول للنظام.
          </p>
        </div>

        <LoginForm />

        <p className="mt-6 border-t border-[#edf1ee] pt-5 text-xs leading-5 text-[#7a847e]">
          في النسخة الأولى يتم إنشاء حسابات الموظفين من Supabase Authentication.
        </p>
      </section>
    </main>
  );
}

