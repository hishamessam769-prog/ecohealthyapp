# ECO Healthy ERP — Production

Production-oriented Next.js + Supabase ERP for ECO Healthy.

## Included modules

- Product Catalog and package sizes.
- Monthly Menu Planner mapped by real service date and package.
- Sales Order Entry: Subscription and Ad-Hoc.
- Payment capture, proof upload to private Supabase Storage, Accounting Gatekeeper.
- Professional client-side PDF invoices.
- Client 360 with financial totals, complaints, dietary rules and delivery history.
- Subscription bulk Kitchen generation from published monthly menu.
- Finite/indefinite Pause, automatic due resume, Custom Menu and price delta.
- Kitchen aggregate quantities and touch-friendly production checklist.
- Delivery by Zone, exact cash expectation, cash logging and CSV routing export.
- Accounting financial visibility, daily cash closing, payment verification.
- Cancellation math and downloadable PDF Cancellation Statement.
- Database-side RPC/trigger enforcement for critical workflows.
- PWA manifest, service worker, mobile-first Kitchen and Delivery.
- Vercel Cron endpoint for the 17:00 Africa/Cairo next-day Kitchen cut-off.

## Setup

1. Run `supabase/database_schema.sql` on a clean Supabase project.
2. Create the first user in Supabase Authentication and set its `employee_profiles.role` to `admin` from Supabase Table Editor/SQL Editor.
3. Add all values from `.env.example` to Vercel. Never expose `SUPABASE_SERVICE_ROLE_KEY` in a `NEXT_PUBLIC_` variable.
4. Deploy the repository to Vercel.
5. In Catalog, create/publish the current Monthly Menu before sending subscriptions to Kitchen.

## Required environment variables

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_REQUIRE_AUTH=true`
- `SUPABASE_SERVICE_ROLE_KEY` (server only)
- `CRON_SECRET` (server only)

## Build check

Run `npm install` then `npm run build`.
