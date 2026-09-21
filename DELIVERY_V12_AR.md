# تسليم V12 — نفّذ بالترتيب

1. خذ Backup من Supabase قبل أي تحديث.
2. لا تشغّل ملف Reset؛ القاعدة الحالية عندك V11 وبها حساب المدير.
3. افتح Supabase SQL Editor وشغّل الملف `deliverables/SUPABASE_UPDATE_V12_AND_DEMO.sql` كاملًا مرة واحدة.
4. النتيجة الصحيحة: `Installed versions: 12` وكل صفوف الفحص `passed = true`.
5. فك ZIP الجديد، واحذف ملفات المشروع القديم من GitHub ثم ارفع محتويات المجلد المفكوك مكانها مع إظهار الملفات المخفية مثل `.env.example`، ومنع رفع `.env.local`.
6. Vercel سيعمل Deploy تلقائيًا من نفس GitHub. لا تعِد إدخال Environment Variables القديمة ولا تغيّرها ما دام Login يعمل الآن.
7. افتح رابط Vercel ثم اتبع `ACCEPTANCE_REVIEW_AR.md`.

## ما أضيف

- 32 سعرًا مطابقًا لصور Muscles Gain وWeight Loss.
- منيو 31 يومًا وربط الوجبات بنوع Lunch/AM/PM/FullDay.
- 12 مشتركًا تجريبيًا بحالات مختلفة وعناوين وGPS وZones ومواعيد توصيل.
- Bulk Skip وExtra Portions وConfirm Delivered وكشف إنتاج قابل للطباعة.
- Freeze مع إنشاء أيام بديلة تلقائيًا.
- Refund محسوب من الأيام المتبقية مع بيانات InstaPay/Wallet واعتماد Finance وإثبات دفع وClawback.
- 8 مهام تشغيلية تجريبية و5 أنواع حسابات قبول منفصلة.
- صفحة عميل جديدة تمنع تكرار الموبايل وتلزم بيانات التوصيل قبل الاشتراك.

## مهم

هذا التحديث لا يرسل WhatsApp أوGoogle Calendar حقيقيًا؛ تلك التكاملات ما زالت تحتاج Credentials فعلية. البيانات الموجودة هنا Demo/Staging فقط وليست بيانات Production.
