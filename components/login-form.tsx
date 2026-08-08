"use client";

import { useState } from "react";
import { LogIn } from "lucide-react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setLoading(true);

    try {
      if (
        !process.env.NEXT_PUBLIC_SUPABASE_URL ||
        !process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
      ) {
        setError("أضف بيانات Supabase في Environment Variables أولاً.");
        return;
      }

      const supabase = createClient();
      const { error: authError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (authError) {
        setError("البريد الإلكتروني أو كلمة المرور غير صحيحة.");
        return;
      }

      router.replace("/");
      router.refresh();
    } finally {
      setLoading(false);
    }
  }

  return (
    <form onSubmit={submit} className="space-y-5">
      <div>
        <label htmlFor="email" className="mb-2 block text-sm font-semibold text-[#28342d]">
          البريد الإلكتروني
        </label>
        <input
          id="email"
          type="email"
          autoComplete="email"
          required
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="name@ecohealthy.com"
          className="min-h-12 w-full border border-[#cfd9d2] bg-white px-4 text-left text-sm outline-none transition-colors placeholder:text-[#a0aaa3] focus:border-[#16794a]"
          dir="ltr"
        />
      </div>

      <div>
        <label htmlFor="password" className="mb-2 block text-sm font-semibold text-[#28342d]">
          كلمة المرور
        </label>
        <input
          id="password"
          type="password"
          autoComplete="current-password"
          required
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          placeholder="••••••••"
          className="min-h-12 w-full border border-[#cfd9d2] bg-white px-4 text-left text-sm outline-none transition-colors placeholder:text-[#a0aaa3] focus:border-[#16794a]"
          dir="ltr"
        />
      </div>

      {error ? (
        <p role="alert" className="border-r-4 border-red-600 bg-red-50 px-4 py-3 text-sm text-red-800">
          {error}
        </p>
      ) : null}

      <button
        type="submit"
        disabled={loading}
        className="flex min-h-12 w-full items-center justify-center gap-2 bg-[#16794a] px-4 text-sm font-bold text-white transition-colors hover:bg-[#0f603a] disabled:cursor-wait disabled:opacity-70"
      >
        <LogIn size={19} aria-hidden="true" />
        {loading ? "جاري الدخول..." : "دخول للنظام"}
      </button>
    </form>
  );
}

