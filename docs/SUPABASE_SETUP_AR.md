# إعداد Supabase وتشغيل Foundation

1. أنشئ Supabase project واختر Region مناسبة وقريبة من مصر.
2. من Project Settings → API انسخ Project URL وAnon Key إلى `.env.local`.
3. ضع Service Role Key في `.env.local` محليًا فقط؛ لا تستخدم اسمًا يبدأ بـ`NEXT_PUBLIC_`.
4. اربط Supabase CLI بالمشروع ثم نفّذ `supabase db push`، أو شغّل migrations بالترتيب عبر CI موثوق.
5. غيّر بيانات `BOOTSTRAP_*` ثم نفّذ `pnpm bootstrap:admin` مرة واحدة.
6. احذف bootstrap password من البيئة بعد نجاح العملية ودوّر Service Role Key إذا ظهر في سجل غير آمن.
7. فعّل Email provider واضبط Site URL وRedirect URLs للدومين الفعلي قبل Production.

## ترتيب migrations الحالي

1. `0001_foundation_identity_access.sql`
2. `0002_audit_settings_financial_periods.sql`
3. `0003_foundation_security_hardening.sql`

## تشغيل محلي

```bash
pnpm install
pnpm dev
```

للمعاينة المرئية دون Supabase، استخدم `NEXT_PUBLIC_APP_PREVIEW_MODE=true` محليًا فقط. لا تعتمد المعاينة لاختبار RLS.

## اختبارات RLS

بعد تشغيل Supabase المحلي:

```bash
pnpm dlx supabase@2.117.0 start
pnpm dlx supabase@2.117.0 db reset
pnpm dlx supabase@2.117.0 test db
```

تشمل الاختبارات: RLS الأساسية، عزل الفروع، منع التصعيد الذاتي، منع منح CEO دون الصلاحية الحساسة، فورية سحب الدور، ومنع المستخدم المعلق.

## بيانات Staging التجريبية

بعد migrations وAdmin Bootstrap، ضع كلمات مرور فريدة في `.env.local` ولا تشاركها في Git أوالمحادثة، ثم:

```bash
ALLOW_DEMO_SEED=true pnpm seed:foundation-demo
```

ينشئ ذلك Demo Tenant مستقلًا مع CEO Admin وSales Manager وSales Representative وFinance Accountant وفرعين. أعد `ALLOW_DEMO_SEED=false` فورًا. للحذف:

```bash
ALLOW_DEMO_CLEANUP=true pnpm cleanup:foundation-demo
```

اختبار الواجهة والوحدات:

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```
