"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";

export default function MfaPage() {
  const [factorId, setFactorId] = useState(""); const [qr, setQr] = useState(""); const [code, setCode] = useState(""); const [message, setMessage] = useState("جاري فحص التحقق بخطوتين...");
  useEffect(() => { void (async () => { const supabase = createClient(); const assurance = await supabase.auth.mfa.getAuthenticatorAssuranceLevel(); if (assurance.data?.currentLevel === "aal2") { window.location.href = "/"; return; } const factors = await supabase.auth.mfa.listFactors(); const verified = factors.data?.totp.find((item) => item.status === "verified"); if (verified) { setFactorId(verified.id); setMessage("أدخل الكود من تطبيق المصادقة."); return; } const enrolled = await supabase.auth.mfa.enroll({ factorType: "totp", friendlyName: "ECO Healthy ERP" }); if (enrolled.data) { setFactorId(enrolled.data.id); setQr(enrolled.data.totp.qr_code); setMessage("امسح QR ثم أدخل الكود."); } })(); }, []);
  async function verify() { const supabase = createClient(); const challenge = await supabase.auth.mfa.challenge({ factorId }); if (!challenge.data) { setMessage("تعذر إنشاء التحقق."); return; } const result = await supabase.auth.mfa.verify({ factorId, challengeId: challenge.data.id, code }); if (result.error) setMessage("الكود غير صحيح."); else window.location.href = "/"; }
  return <main className="grid min-h-screen place-items-center bg-[#f4f7f5] p-6"><section className="w-full max-w-md rounded-xl border bg-white p-7 shadow-sm"><h1 className="text-2xl font-black">التحقق بخطوتين</h1><p className="mt-2 text-sm text-[#66736b]">{message}</p>{qr ? <img src={qr} alt="QR لتطبيق المصادقة" className="mx-auto my-5 size-52"/> : null}<input value={code} onChange={(event)=>setCode(event.target.value)} inputMode="numeric" dir="ltr" placeholder="000000" className="mt-5 min-h-12 w-full rounded-lg border px-4 text-center text-xl tracking-[.4em]"/><button onClick={verify} disabled={!factorId || code.length < 6} className="mt-3 min-h-12 w-full rounded-lg bg-[#16794a] font-bold text-white disabled:opacity-50">تأكيد</button></section></main>;
}
