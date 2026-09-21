# ارفع وشغّل الآن — Eco Healthy ERP

هذه الحزمة تتضمن ملف Reset مخصصًا لاستبدال قاعدة ERP القديمة داخل مشروع Supabase الحالي بناءً على موافقة مالك المشروع على المسح.

## 1. Supabase

1. افتح مشروع Supabase المخصص لـEcoHealthy App وتأكد أنه ليس مستخدمًا لأي نظام آخر.
2. افتح SQL Editor ثم New Query.
3. افتح الملف `SUPABASE_RESET_AND_INSTALL_V11.sql` الموجود بجوار ملف ZIP، وانسخ محتواه كاملًا ثم اضغط Run مرة واحدة.
4. بعد نجاحه نفّذ:

```sql
select * from public.validate_eco_healthy_installation();
```

يجب أن تكون كل قيمة في عمود `passed` مساوية لـ`true`، وأن يظهر `Installed versions: 11`.

هذا الملف يمسح نهائيًا كل الجداول والبيانات والدوال القديمة داخل `public` ثم يثبت النسخة الجديدة. لا يمسح Supabase Auth Users أوالملفات الفعلية في Storage. إذا أردت استخدام نفس بريد Admin القديم، احذف المستخدم القديم أولًا من Authentication > Users. أفرغ Bucket `erp-attachments` يدويًا إذا أردت حذف المرفقات القديمة أيضًا. لا تشغّل ملف Demo قبل إنشاء أول Admin.

## 2. GitHub

1. أنشئ Repository خاصًا وفارغًا.
2. فك ضغط `eco-healthy-erp-github-ready-v11.zip`.
3. ارفع **محتويات المجلد الناتج** إلى جذر الـRepository، وليس ملف ZIP نفسه.
4. تأكد أن `package.json` و`src` و`supabase` تظهر مباشرة في جذر المستودع.

لا ترفع `.env.local` أو`.env.staging` أوأي كلمة مرور أوService Role Key.

## 3. Vercel

استورد الـRepository واضبط المتغيرات التالية من Supabase Project Settings ومن اختيارك:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY
SUPABASE_SERVICE_ROLE_KEY
SETUP_SECRET
NEXT_PUBLIC_APP_PREVIEW_MODE=false
NEXT_PUBLIC_APP_URL=https://YOUR-VERCEL-DOMAIN
```

`SETUP_SECRET` يجب أن يكون سرًا جديدًا لا يقل عن 32 حرفًا. لا تضف `STAGING_DATABASE_URL` أوكلمات مرور E2E إلى Vercel.

بعد أول Deploy حدّث `NEXT_PUBLIC_APP_URL` بالرابط الحقيقي ثم نفّذ Redeploy.

## 4. إنشاء أول Admin

1. افتح `https://YOUR-VERCEL-DOMAIN/setup`.
2. أدخل بيانات الشركة وأول CEO Admin و`SETUP_SECRET`.
3. بعد النجاح افتح `/login` وسجّل الدخول.
4. صفحة `/setup` تتوقف عن قبول إعداد ثانٍ تلقائيًا.

## 5. بيانات العرض الاختيارية

بعد إنشاء أول Admin فقط، يمكنك تشغيل `outputs/02_install_demo_data.sql` من SQL Editor لإضافة بيانات تجريبية واضحة. لحذفها شغّل `outputs/03_remove_demo_data.sql`.

بيانات العرض لا تنشئ كلمات مرور أوAuth Users إضافيين. أنشئ مستخدمي Sales وFinance وOperations من شاشة الإدارة، وشارك كلمات المرور خارج GitHub.

## 6. فحص سريع

1. أنشئ Customer وQuotation من Sales.
2. Accept ثم Convert to Invoice.
3. ارفع Payment Proof واختر الفاتورة يدويًا.
4. ادخل بحساب Finance مختلف واعتمد Partial أوFull.
5. فعّل Subscription بحساب Operations.
6. أكد Delivered Day وتحقق من Revenue Entry.
7. نفّذ Refund وتحقق من Cash Reversal وCommission Clawback.

الدورة نفسها اجتازت اختبار Hosted Supabase ومتصفح Production محلي، ونتائجها موجودة داخل `outputs/hosted-e2e` دون مفاتيح أوكلمات مرور.
