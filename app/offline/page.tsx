export default function OfflinePage() {
  return (
    <main dir="rtl" className="flex min-h-screen items-center justify-center bg-[#f4f7f5] p-6">
      <div className="w-full max-w-md rounded-lg border border-[#dce5df] bg-white p-6 text-center">
        <div className="mx-auto mb-4 flex size-14 items-center justify-center rounded-md bg-[#16794a] font-bold text-white">ECO</div>
        <h1 className="text-xl font-bold text-[#17211b]">أنت الآن بدون إنترنت</h1>
        <p className="mt-2 text-sm leading-6 text-[#66736b]">شاشات التشغيل التي فتحتها سابقًا ستظل متاحة من الذاكرة المؤقتة. أعد المحاولة عند عودة الشبكة.</p>
      </div>
    </main>
  );
}
