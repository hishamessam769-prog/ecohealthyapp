# ECO Healthy ERP

نسخة MVP تفاعلية كاملة مبنية بـ Next.js وTailwind CSS ومكونات Shadcn/Radix، مع مخطط Supabase شامل وPWA.

## الشاشات

- Dashboard تشغيلية بسيطة.
- CRM للعملاء والشكاوى وروابط الصور.
- اشتراكات متعددة للعميل، Pause/Resume وMeal Swap وطلب الإلغاء.
- Kitchen checklist مع Cut-off وVIP override وحالات الإنتاج.
- Delivery حسب Zone، تعيين Rider، Cash/Card/InstaPay وتسجيل التسليم.
- Accounting: PayOnFirstDelivery Gatekeeper وRefund workflow.
- Sales: Target، الإيراد المؤكد، وCommission tiers.
- Smart Notifications حسب الدور.
- Offline service worker وManifest لتجربة PWA.

## وضع الـDemo

الواجهة تحتوي على بيانات Mock جاهزة داخل `components/erp-provider.tsx`، لذلك يمكن تجربة كل الأزرار بدون إعداد قاعدة بيانات. غيّر الدور التجريبي من أعلى الشاشة لرؤية القوائم المناسبة لكل قسم.

## Supabase

شغّل `supabase/schema.sql` مرة واحدة على مشروع Supabase جديد. الملف ينشئ الجداول والعلاقات وRLS وRPCs والتريجرز الخاصة بالـCut-off والدفع والتوصيل والإلغاء والعمولات والتنبيهات.

## Environment Variables

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_REQUIRE_AUTH=false` للـDemo الجاهز.

غيّر `NEXT_PUBLIC_REQUIRE_AUTH=true` عندما تريد تفعيل Login عبر Supabase Auth.

## تشغيل محلي

`npm install`

`npm run dev`

## Production check

`npm run build`
