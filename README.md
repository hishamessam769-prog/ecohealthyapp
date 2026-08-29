# ECO Healthy ERP v4

Production-ready Next.js 16 frontend for ECO Healthy meal subscriptions. The project uses App Router, TypeScript, Tailwind CSS, Radix/Shadcn-style components, Supabase Auth/RLS/RPC, PWA, Excel export and browser-generated PDF invoices/statements.

## Run the interactive demo

1. `npm install`
2. Copy `.env.example` to `.env.local`.
3. Keep `NEXT_PUBLIC_DEMO_MODE=true` and `NEXT_PUBLIC_REQUIRE_AUTH=false`.
4. `npm run dev`

Demo changes persist in localStorage. Use **إعادة بيانات التجربة** to reset the complete scenario or **حذف بيانات التجربة** after testing.

## Connect Supabase

1. Run `supabase/eco_healthy_schema.sql` in a new Supabase SQL Editor query.
2. Set the project URL and publishable key.
3. Set `NEXT_PUBLIC_DEMO_MODE=false` and `NEXT_PUBLIC_REQUIRE_AUTH=true`.
4. Create the first account from the login screen. The database promotes the first employee to Admin.

## Vercel

Import the repository and add the same four public environment variables. No service-role key is required by the browser application and no paid Cron is configured.

## Core workflow

Client → Order → Accounting verification → Subscription/menu schedule → Kitchen → Delivery/COD → Reconciliation. Cancellation and commission workflows are enforced by database RPC functions and RLS.
