"use client";

import { AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";

export default function AppError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return <div className="surface mx-auto mt-16 max-w-xl rounded-2xl p-8 text-center"><span className="mx-auto grid size-14 place-items-center rounded-2xl bg-red-50 text-red-700"><AlertTriangle size={26} /></span><h1 className="mt-5 text-xl font-black">تعذر تحميل الصفحة</h1><p className="mt-2 text-sm leading-6 text-[var(--text-muted)]">حدث خطأ غير متوقع. لم يتم حفظ أي تغيير غير مؤكد. حاول مرة أخرى، وإذا استمر الخطأ تواصل مع مسؤول النظام.</p><Button className="mt-6" onClick={reset}>إعادة المحاولة</Button></div>;
}
