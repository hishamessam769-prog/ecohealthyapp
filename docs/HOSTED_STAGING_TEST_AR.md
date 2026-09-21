# اختبار Hosted Supabase Staging

هذا الاختبار مخصص لمشروع Staging جديد وقابل للحذف فقط. لا تستخدم مشروع Production.

1. انسخ `.env.example` إلى `.env.staging` وأدخل القيم الحقيقية محليًا. الملف مستبعد من Git.
2. ثبّت Supabase CLI الرسمي، ثم شغّل `pnpm staging:install-master`. هذا يرفع **نفس** `outputs/01_install_complete_database.sql` كـMigration واحدة إلى قاعدة Staging الفارغة.
3. شغّل `pnpm staging:verify`؛ يجب أن يثبت 11 Schema Versions وكل Validation Checks.
4. شغّل `pnpm staging:prepare` لإنشاء ثلاثة حسابات Staging وأقل Reference Data لازمة. لا تُكتب كلمات المرور أوService Role Key في ملفات الأدلة.
5. شغّل التطبيق بوضع Production وبـ`NEXT_PUBLIC_APP_PREVIEW_MODE=false`، أوانشره على Staging، وضع رابطه في `HOSTED_E2E_BASE_URL`.
6. شغّل `pnpm test:e2e:hosted`.

المخرجات المتوقعة داخل `outputs/hosted-e2e`:

- `hosted-install-validation.json`: إثبات تثبيت Master SQL على Hosted.
- `preflight.json`: معرفات بيئة الاختبار بدون أسرار.
- `results.json`: نتيجة Playwright.
- `evidence/*.png`: Screenshots لكل مرحلة.
- `evidence/*.json`: Database Before/After لكل مرحلة.
- `artifacts/**/video.webm`: فيديو كامل للدورة.
- `artifacts/**/trace.zip`: Trace للتدقيق الفني.

الاختبار يستخدم Sales User لإنشاء العميل والعرض والفاتورة وPayment Proof، ثم Finance User مختلفًا لاعتماد Partial وFull، ثم Operations User لتفعيل الاشتراك وتأكيد يوم الخدمة، ثم ينفذ Refund وClawback. أي محاولة لاستخدام المستخدم نفسه للإرسال والاعتماد تفشل في قاعدة البيانات.
