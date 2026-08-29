# Enterprise implementation checklist

| المجال | التنفيذ | الدليل التنفيذي |
|---|---|---|
| P0 Security | مكتمل | No public signup، دعوات، MFA، RLS، API permissions، scoped read models، private Storage |
| P0 Finance | مكتمل | NUMERIC، server pricing، immutable invoice lines/journals، allocations، deferred revenue |
| Idempotency | مكتمل | command keys، gateway event uniqueness، atomic payment activation، terminal delivery |
| Roles | مكتمل | 18 role + effective dates + multiple roles + Dalia Operations Manager |
| CRM/Sales | مكتمل | Leads/campaigns/activities/tasks/conversations/assignments + scoped dashboards |
| Targets/Commission | مكتمل | versioned plans/tiers/targets/maturity/accrual/payable/reversal/payout |
| Subscription | مكتمل | cycles/entitlements/ledger/change preview+commit/pause/skip/swap/renewal |
| Kitchen/QA | مكتمل | demand/BOM/batches/yield/waste/QA/labels/cutoff/exceptions |
| Inventory | مكتمل | ingredients/UOM/PO/receipts/lots/append-only stock ledger/counts |
| Delivery/Cash | مكتمل | routes/stops/state machine/offline queue/POD/custody/handover/reconciliation |
| Accounting | مكتمل | COA/journals/periods/banks/revenue schedule/credits/refunds/close blockers |
| Dashboards | مكتمل | CEO/Sales/Finance/Operations/Investor role-specific read models |
| KPI/Planning | مكتمل | versioned definitions, numerator/denominator, snapshots, targets/reforecasts |
| Integrations | مكتمل | `/api/v1`, signed upload, webhook signature/replay protection, outbox/jobs |
| UX/PWA | مكتمل | Arabic RTL, 44px actions, responsive tables, errors/loading/empty/offline sync |
| Migration | مكتمل | legacy mapping guidance + discrepancy views + `MISSING_LEGACY_EVIDENCE` |
| Tests | مكتمل | unit/property/policy/migration/RLS/API/E2E/offline/load procedures |

لا يُعد أي صف مقبولًا في الإنتاج قبل نجاح `npm run test:all` واختبارات Supabase Staging الواردة في `docs/UAT_AR.md`.

