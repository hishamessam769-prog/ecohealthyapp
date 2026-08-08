# ECO Healthy ERP — MVP

نسخة أولى عملية مبنية بـ Next.js + Tailwind CSS + Supabase.

النسخة الحالية تحتوي على:

- تسجيل دخول الموظفين عن طريق Supabase Auth.
- Dashboard رئيسي.
- عدد العملاء والاشتراكات الفعالة.
- تنبيه الاشتراكات التي يتبقى لها 3 أيام أو أقل.
- شاشة طابور مطبخ Mobile-First.
- فصل الأوردر المالي عن أيام التنفيذ اليومية.
- RLS لحماية الجداول من المستخدم غير المسجل.
- Manifest لتجهيز التطبيق كتطبيق ويب.

التصميم Flat وبألوان أخضر وأبيض ورمادي وأزرق فقط. لا يوجد Gold أو نجوم أو أهرامات.

## 1) تجهيز Supabase

1. افتح مشروع Supabase.
2. افتح SQL Editor.
3. افتح الملف `supabase/schema.sql` من المشروع.
4. انسخ الملف بالكامل داخل SQL Editor.
5. اضغط Run.
6. يجب أن تظهر رسالة نجاح بدون Error.

### بيانات تجريبية اختيارية

لو عايز تشوف الداشبورد والمطبخ ببيانات فوراً:

1. افتح `supabase/seed-demo.sql`.
2. انسخه إلى SQL Editor.
3. اضغط Run.

لا تشغل ملف الـDemo لو هتبدأ بإدخال عملاء حقيقيين مباشرة.

## 2) إنشاء أول حساب موظف

مهم: شغّل `schema.sql` أولاً قبل إنشاء أول User.

1. من Supabase افتح Authentication.
2. افتح Users.
3. اختر Add User.
4. أدخل إيميل وكلمة مرور للموظف.
5. أنشئ الحساب.

أي مستخدم جديد يأخذ دور `cs` تلقائياً.

لتحويل أول حساب إلى Admin شغّل في SQL Editor بعد تغيير الإيميل في الأمر التالي:

```sql
update public.employee_profiles
set role = 'admin'
where user_id = (
  select id from auth.users where email = 'YOUR_EMAIL_HERE'
);
```

## 3) بيانات الاتصال بـ Supabase

من Supabase افتح Connect وانسخ:

- Project URL
- Publishable key

محلياً أنشئ ملف `.env.local` واكتب:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_YOUR_KEY
```

لا تضف Service Role Key إلى المشروع أو GitHub.

## 4) تشغيل المشروع على الكمبيوتر

داخل فولدر المشروع:

```bash
npm install
npm run dev
```

بعدها افتح:

`http://localhost:3000`

## 5) رفع المشروع على GitHub

الطريقة الأسهل لو مش بتستخدم Git Commands:

1. افتح GitHub.
2. اختر New repository.
3. سمّه مثلاً `eco-healthy-erp`.
4. افتح الريبو واضغط Add file ثم Upload files.
5. ارفع كل محتويات فولدر المشروع.
6. لا ترفع `.env.local`.
7. اضغط Commit changes.

## 6) Deploy على Vercel

1. افتح Vercel.
2. اختر Add New ثم Project.
3. اختر GitHub repository الخاص بالمشروع.
4. Vercel سيتعرف على Next.js تلقائياً.
5. قبل Deploy افتح Environment Variables.
6. أضف:

```text
NEXT_PUBLIC_SUPABASE_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
```

7. ضع القيم التي أخذتها من Supabase.
8. اضغط Deploy.

بعد انتهاء الـDeploy افتح رابط Vercel وسجّل الدخول بحساب الموظف الذي أنشأته في Supabase.

## ملفات مهمة

```text
app/page.tsx                 Dashboard
app/kitchen/page.tsx         شاشة المطبخ
app/login/page.tsx           تسجيل الدخول
components/                  مكونات الواجهة
lib/data.ts                  قراءة البيانات من Supabase
lib/supabase/                اتصال Supabase
proxy.ts                     حماية الصفحات وتجديد Session
supabase/schema.sql          قاعدة البيانات الأساسية
supabase/seed-demo.sql       بيانات اختبار اختيارية
```

