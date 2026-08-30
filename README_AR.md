# ECO Healthy ERP — دليل التشغيل والإدارة

هذه النسخة هي نظام ERP/CRM عربي يعمل ببيانات Supabase الحية. المتصفح لا يحمل بيانات الشركة كلها، ولا توجد بيانات تشغيل في `localStorage`، وكل الأسعار والمدفوعات والاستحقاقات والعمولات تُحسم على الخادم/قاعدة البيانات.

## ما تم تنفيذه

- 18 دورًا بصلاحيات مؤرخة، فرق عمل، دعوات موظفين، تعطيل موظف، وإلزام MFA للأدوار المالية والإدارية الحساسة.
- CRM: Leads وحملات ومحادثات وأنشطة ومهام وإسناد العميل لموظف المبيعات.
- كتالوج بإصدارات Package/Price/Menu غير قابلة للتغيير بأثر رجعي.
- إنشاء فاتورة بسعر محسوب من Price Book، خطوط فاتورة ثابتة، إثبات دفع خاص ومشفّر المسار، واعتماد محاسبي ذري.
- اشتراكات ودورات وEntitlement Ledger وتغييرات Pause/Skip/Swap عبر Preview ثم Commit.
- عمولات وأهداف قابلة للتهيئة بإصدارات وTiers غير متداخلة، ومراحل Pending Maturity وPayable وClawback.
- مطبخ فعلي: Demand وBatch وBOM ومخزون وحركة مخزون وجودة؛ لا يخرج Batch للتوصيل قبل QA Release.
- توصيل: Routes/Stops وحالة مقيدة، Rider PWA، Offline Queue آمنة ومتزامنة دون تكرار.
- تحصيل نقدي بسلسلة عهدة؛ تسجيل Rider لا يساوي تحقق Finance.
- قيود محاسبية مزدوجة، إيراد مؤجل/معترف، Refund/Credit Note، ومعوقات إقفال.
- CEO/Sales/Operations/Finance/Investor dashboards من Read Models محدودة حسب الدور، وليست Bootstrap شاملًا.
- Outbox وJobs وWebhook idempotency وAudit وError IDs وملفات Excel محكومة بالصلاحيات وفاتورة احترافية قابلة للطباعة والمشاركة.

## مسارات التشغيل الأساسية في هذه النسخة

### سجل العملاء

1. افتح **سجل العملاء والمشتركين** واضغط **عميل جديد**.
2. الاسم والهاتف والعنوان والمنطقة إلزامية. أضف رابط Google Maps أو خط العرض والطول، وموعد التوصيل المفضل.
3. يظهر العميل فورًا حتى قبل إنشاء اشتراك له.
4. زر **تحميل Excel** ينزل حتى 5000 عميل مسموح للحساب بعرضهم، مع الهاتف والعنوان واللوكيشن ومسؤول المبيعات والاشتراك الحالي.

### قائمة الأسعار والفاتورة

1. من **الكتالوج والتسعير** أضف البرنامج: Weight Loss أو Muscle Gain.
2. اختر Lunch Only أو AM أو BM أو Full Day، ثم 6/12/18/24 يومًا، والحجم Regular/Hero، والسعر وتاريخ السريان.
3. من **الطلبات والفواتير** اختر إما باكدج من قائمة الأسعار أو اشتراك خاص باسمه وسعره وعدد أيامه.
4. الإدارة تحدد أقصى خصم من زر **تحديد حد الخصم**. الخادم يرفض أي نسبة أعلى.
5. سجّل طريقة الدفع وتاريخ الدفع وتاريخ بدء الاشتراك والمرجع. ارفع الإثبات للمدفوعات غير النقدية.
6. الفاتورة تظهر فورًا ويمكن طباعتها أو حفظها PDF أو مشاركة رابطها، لكن الاشتراك لا يتفعل قبل اعتماد المحاسب.

### المحاسب والاشتراكات والعمولات

1. المحاسب يرى اسم الاشتراك، تاريخ الدفع، تاريخ البدء، المبلغ، المرجع، وحالة الإثبات.
2. بعد الاعتماد الذري يظهر البيع لدى موظف المبيعات **مدفوع — منتظر الاستحقاق**.
3. من **محرك العمولات** تُنشأ الشرائح من أزرار وصفوف، بدون JSON. الإعداد الافتراضي خمسة أيام ويمكن تغييره.
4. من **الأهداف والخطة** يمكن اعتماد هدف الشركة وهدف كل موظف شهريًا.
5. طلب الإلغاء لا ينفذ مباشرة؛ يُحسب الاسترداد في الخادم ويراجعه المحاسب ثم يوافق أو يرفض.

### التوصيل والتحصيل

1. العبوات التي اجتازت QA تظهر جاهزة للتوجيه.
2. مسؤول التوصيل ينشئ Route لليوم والمنطقة والنافذة ويختار المندوب؛ العملاء والعبوات والتحصيل النقدي تُضاف تلقائيًا.
3. اضغط **إرسال للمندوب**. المندوب يرى على الهاتف محطاته فقط، والهاتف والعنوان وعدد العبوات والمبلغ المطلوب.
4. زر اللوكيشن يفتح الملاحة مباشرة، والتسليم والتحصيل يعملان بشكل idempotent حتى بعد Offline Sync.
5. مسؤول التوصيل يستطيع تنزيل manifest كملف Excel، والمحاسب يستلم عهدة الكاش في نهاية اليوم.

## 1) إنشاء Supabase

1. أنشئ ثلاثة مشاريع منفصلة: Development وStaging وProduction.
2. من Authentication عطّل **Allow new users to sign up**.
3. فعّل Email Provider وMFA (TOTP) وسياسة كلمات مرور قوية.
4. لا تضع `service_role` في أي متغير يبدأ بـ`NEXT_PUBLIC_`.

## 2) تثبيت قاعدة البيانات

على مشروع جديد افتح SQL Editor وشغّل الملف `supabase/eco_healthy_schema_final.sql` مرة واحدة. الملف يحتوي migrations مؤرخة داخليًا ويمكن إعادة تشغيله بأمان؛ لن ينشئ أنواع Enum متعارضة ولن يثبت Demo Data تلقائيًا.

للفرق التي تستخدم Supabase CLI:

1. اربط المشروع: `npx supabase link --project-ref PROJECT_REF`
2. ادفع migration: `npx supabase db push`
3. راجع `public.eco_schema_migrations` بعد التنفيذ.

لا تعدّل migration منفذة. أي تغيير لاحق يكون ملفًا جديدًا داخل `supabase/migrations`.

## 3) إنشاء أول System Admin

1. اضبط `ADMIN_BOOTSTRAP_SECRET` في البيئة ثم أعد Deploy.
2. أرسل طلب POST مرة واحدة إلى `/api/v1/admin/bootstrap` وبداخله `secret` و`email` و`password` (12 حرفًا على الأقل) و`fullName`. المسار ينشئ Auth User والموظف ودور System Admin ذريًا، ويرفض العمل نهائيًا بعد وجود أول موظف.
3. سجّل الدخول وفعّل TOTP من شاشة MFA قبل دخول النظام.

بعد ذلك كل موظف جديد يُنشأ من **الإدارة → دعوة موظف** مع دور أو أكثر. الدعوة تربط Auth User بالموظف ولا تمنح Admin تلقائيًا.

## 4) متغيرات البيئة

انسخ `.env.example` إلى `.env.local` واكتب القيم الحقيقية:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` — خادم فقط
- `ADMIN_BOOTSTRAP_SECRET`
- `CRON_SECRET`
- `PAYMENT_WEBHOOK_SECRET`
- `NEXT_PUBLIC_APP_ENV=development|staging|production`
- `NEXT_PUBLIC_APP_URL`

النسخة تفشل مغلقة برسالة Configuration Error إذا كانت إعدادات Supabase ناقصة؛ لا يوجد انتقال صامت إلى Demo.

## 5) التشغيل محليًا

1. ثبّت Node.js 22 أو أحدث.
2. نفّذ `npm install`.
3. نفّذ `npm run typecheck` ثم `npm test` ثم `npm run build`.
4. شغّل `npm run dev` وافتح `http://localhost:3000`.

## 6) النشر على Vercel

1. ارفع محتويات المشروع إلى Repository مملوك لـECO Healthy.
2. اربطه بـVercel وأضف متغيرات البيئة لكل من Preview وProduction.
3. اجعل Production branch هو `main`، ولا ترفع `.env.local`.
4. اضبط Job يومي يستدعي `/api/v1/jobs/renewals` و`auto-resume` و`outbox` بهيدر `Authorization: Bearer CRON_SECRET`.
5. Deploy ثم اختبر Login وMFA ورفض URL غير المصرح.

## 7) سيناريو الاختبار الكامل

1. من الإدارة اضغط **تثبيت Demo Data**. الإجراء يثبت بيانات الأساس ثم Full Demo ثم سجل عشرة أيام، وكلها مميزة بـ`is_demo`.
2. بدور Sales Agent: افتح سجل العملاء، أنشئ Customer كامل العنوان واللوكيشن ثم Invoice من الكتالوج أو بسعر خاص.
3. من Orders ارفع PNG/JPEG/PDF كإثبات. الملف يذهب إلى bucket خاص وتُحفظ بصمته SHA-256.
4. بدور Accountant: افتح Accounting، راجع الإثبات، ثم Verify Payment. يجب أن تنشأ Subscription واحدة فقط وتظهر Paid — Pending Maturity للمبيعات.
5. أعد الضغط/الطلب بنفس Idempotency Key: يجب أن ترجع نفس النتيجة دون Subscription أو Credit مكرر.
6. من Subscriptions نفّذ Preview لـPause/Skip/Swap، راجع الأثر، ثم Commit.
7. من Kitchen أنشئ Batch من Demand، أدخل الإنتاج، ثم بدور QA Officer أطلق QA Release.
8. من Delivery أنشئ Route وعيّن Rider، ثم اضغط إرسال للمندوب. Rider يرى مساره فقط ويسجل Arrived ثم Delivered.
9. افصل الشبكة على هاتف Rider، سجّل الحدث، ثم أعد الشبكة. Pending Sync يعود صفرًا ولا يتكرر Delivery/Entitlement.
10. Rider يعلن Cash في العهدة؛ لا يصبح Verified حتى يستلمه Accountant ويطابق Handover.
11. راجع CEO: Booked، Pending Maturity، Confirmed، الإيراد المؤجل/المعترف، SLA والمعوقات.
12. بدور Investor تأكد أنه يرى Certified KPIs فقط بلا اسم/هاتف/عنوان/غذاء.

## 8) حذف بيانات التجربة

من الإدارة اضغط **حذف Demo Data**. الحذف يستهدف الصفوف التجريبية وعلاقاتها فقط. Production لا يثبت Demo Data تلقائيًا ولا يجب تشغيله على قاعدة حقيقية إلا من حساب مخول.

## 9) النسخ الاحتياطي والاستعادة

- فعّل Supabase PITR للـProduction حسب خطة المؤسسة.
- نسخة منطقية: `supabase db dump --linked -f backup.sql` واحفظها مشفرة خارج Repository.
- اختبر الاستعادة شهريًا إلى مشروع معزول، شغّل migration tests، قارن أعداد العملاء والفواتير والقيود، ثم أتلف بيئة الاختبار.
- قبل أي Migration: Snapshot/PITR bookmark، Dry Run على Staging، ثم Production في نافذة صيانة. الرجوع يتم Restore/PITR أو Migration تعويضية؛ لا تعدّل التاريخ المنشور.

## 10) استكشاف الأخطاء

- `type already exists`: لا تستخدم SQL قديمًا؛ شغّل الملف النهائي الذي لا يعتمد Enums مخصصة.
- `min(uuid)` أو `max(uuid)`: النسخة النهائية تستخدم `array_agg(...)[1]` ولا تستخدم Aggregate غير مدعوم على UUID.
- `relation ... does not exist`: الواجهة وSQL ليسا من الإصدار نفسه؛ شغّل `supabase/eco_healthy_schema_final.sql` ثم أعد تحميل schema cache.
- `CONFIG`: راجع متغيرات Vercel وأعد Deploy.
- `FORBIDDEN`: الحساب غير مربوط بموظف/دور فعال أو MFA غير مكتمل.
- Proof غير ظاهر: تأكد أن Storage bucket خاص وأن خطوة complete نجحت.
- خطأ تشغيل: احتفظ بـError ID وابحث عنه في Structured Logs/Audit دون نشر أسرار.

## ملفات المراجعة

- `IMPLEMENTATION_CHECKLIST.md`: تغطية المتطلبات.
- `docs/MIGRATION_PLAN_AR.md`: نقل بيانات الـMVP وتقارير الفروق.
- `docs/UAT_AR.md`: اختبارات قبول مفصلة.
- `docs/ECO_Healthy_Turnaround_Exit_Manifesto_2027_2029.html`: الخطة الاستراتيجية الأصلية ذات 48 صفحة.
- `docs/STRATEGIC_IMPLEMENTATION_APPENDIX_AR.md`: ربط الخطة بالتنفيذ.
