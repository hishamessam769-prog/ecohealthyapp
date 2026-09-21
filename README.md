# Eco Healthy ERP

نظام ERP عربي/إنجليزي مبني بـ Next.js 16 وTypeScript وSupabase/PostgreSQL. الحزمة تشمل Foundation، المشاريع والمهام، CRM، المبيعات والاشتراكات، التحصيل والعمولات، جلسات الأطباء ومحاسبتهم، وبنية التكاملات.

## ما يعمل

- تسجيل الدخول، `/setup` لأول Admin مرة واحدة، المستخدمون والأدوار والصلاحيات والفروع وAudit Log.
- واجهة RTL متجاوبة مع App Launcher وSidebar وTop Bar والبحث والإشعارات وصندوق الاعتمادات.
- المشاريع والمهام والمتابعات والرد الرسمي والأدلة والمراجعة والتصعيد والإشعارات عبر Outbox.
- Leads والتحويل إلى Customer 360 والتفضيلات والحساسية والشكاوى وTimeline.
- Packages بإصدارات سعرية، Quotations، Invoices، Payment Proof، اعتماد Finance، Cash Collection، الاشتراك والتجميد والإلغاء والاسترداد وDeferred Revenue.
- Targets وSales Commissions وClawback بعد Refund.
- دليل الأطباء والخدمات والإتاحة ومنع Double Booking والتوزيع Round Robin والجلسات والملاحظات والتوصيات والتقييم.
- Doctor Commissions وStatements وPayouts مع Maker–Checker.
- Provider architecture لـIn-App وEmail وWhatsApp وGoogle Calendar/Meet مع Retry وIdempotency. المزودات الخارجية تعمل Mock حتى إضافة Credentials.

## أسرع تركيب

1. أنشئ Supabase Project جديدًا.
2. شغّل `outputs/01_install_complete_database.sql` كاملًا في SQL Editor.
3. انسخ `.env.example` إلى `.env.local` محليًا، أو أدخل القيم نفسها في Vercel Environment Variables.
4. اضبط `NEXT_PUBLIC_SUPABASE_URL` و`NEXT_PUBLIC_SUPABASE_ANON_KEY` و`SUPABASE_SERVICE_ROLE_KEY` و`SETUP_SECRET`.
5. ثبّت وشغّل: `pnpm install && pnpm build && pnpm start`.
6. افتح `/setup` وأنشئ أول Admin. تتعطل الصفحة تلقائيًا بعد نجاحها.
7. اختياريًا شغّل `outputs/02_install_demo_data.sql`، واحذف التجريبي فقط عبر `outputs/03_remove_demo_data.sql`.

راجع `outputs/START_HERE_AR.pdf` للخطوات المختصرة المصورة.

## المتغيرات والأسرار

- القيم التي تبدأ بـ`NEXT_PUBLIC_` فقط مسموح عرضها للمتصفح.
- `SUPABASE_SERVICE_ROLE_KEY` و`SETUP_SECRET` Server-only ولا توضع في GitHub.
- لا تحتوي الحزمة على `.env` أو `.env.local` أوTokens أوكلمات مرور فعلية.
- عطّل `NEXT_PUBLIC_APP_PREVIEW_MODE` في الإنتاج.

## قاعدة البيانات

- Master installer: `outputs/01_install_complete_database.sql`.
- 11 migrations مرقمة داخل `supabase/migrations`.
- Demo installer وcleanup منفصلان، وكل سجل تجريبي يحمل `is_demo = true`.
- التثبيت يضيف 98 جدولًا عامًا، 83 Permission، 15 System Role، RLS، Triggers، Audit، Storage policies، وInstallation Validator.

## الاختبارات

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm build
pnpm sql:build
pnpm sql:validate
pnpm sql:test:embedded
PLAYWRIGHT_BROWSERS_PATH=work/pw-browsers pnpm test:e2e
```

اختبارات قاعدة البيانات المضمنة تنفذ الـMaster SQL من قاعدة PostgreSQL فارغة مع عقود `auth` و`storage` الموافقة لـSupabase، ثم تشغّل pgTAP وDemo install/cleanup. كما اجتازت دورة Sales → Finance → Operations → Refund اختبار متصفح حقيقي متصل بـHosted Supabase Staging مع Preview Mode مغلق. يجب مع ذلك تشغيل Master SQL على مشروعك الجديد الفارغ وضبط متغيرات Vercel الخاصة به.

## النشر

- GitHub: ارفع محتويات ZIP بعد فكها إلى مستودع خاص.
- Supabase: شغّل Master SQL، ثم تحقق أن كل صف في `validate_eco_healthy_installation()` يعرض `passed = true`.
- Vercel: Import للمستودع، Framework = Next.js، أضف Environment Variables، ثم Deploy.
- تسجيل الدخول يكون عبر `/login`، والإعداد الأول عبر `/setup` مرة واحدة فقط.

## قيود معلنة

- Google Calendar/Meet وEmail وWhatsApp منفذة كبنية Provider + Mock واختبارات Idempotency/Retry؛ الإرسال الحقيقي يحتاج Credentials وScopes وقوالب مزود فعلية.
- تم اختبار Hosted Supabase Staging فعليًا. لم يُنفّذ نشر Vercel العام أوالربط بحساب GitHub؛ ينفذه مالك الحساب من الحزمة وفق `UPLOAD_NOW_AR.md`.
- بيانات Demo مرجعية ولا تنشئ كلمات مرور لمستخدمين حقيقيين داخل SQL.
