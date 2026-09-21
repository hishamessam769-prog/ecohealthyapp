import { mkdir, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { createClient } from "@supabase/supabase-js";
import { expect, test, type Page } from "@playwright/test";

const evidenceDir = join(process.cwd(), "outputs", "hosted-e2e", "evidence");
const required = [
  "NEXT_PUBLIC_SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY",
  "E2E_SALES_EMAIL", "E2E_SALES_PASSWORD", "E2E_FINANCE_EMAIL", "E2E_FINANCE_PASSWORD",
  "E2E_OPERATIONS_EMAIL", "E2E_OPERATIONS_PASSWORD",
] as const;
for (const key of required) if (!process.env[key]) throw new Error(`${key} is required for hosted E2E.`);

const admin = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, { auth: { persistSession: false, autoRefreshToken: false } });
const runId = Date.now();
const customerName = `Hosted E2E ${runId}`;
const customerMobile = `010${String(runId).slice(-8)}`;
const proofPng = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=", "base64");

async function login(page: Page, email: string, password: string) {
  await page.context().clearCookies();
  await page.goto("/login");
  await page.locator('input[name="email"]').fill(email);
  await page.locator('input[name="password"]').fill(password);
  await page.getByRole("button", { name: "دخول آمن" }).click();
  await expect(page).toHaveURL(/\/dashboard/);
}

async function shot(page: Page, name: string) {
  await page.screenshot({ path: join(evidenceDir, `${name}.png`), fullPage: true });
}

async function snapshot(stage: string) {
  const { data: customer } = await admin.from("customers").select("*").eq("full_name", customerName).maybeSingle();
  const customerId = customer?.id;
  const { data: quotations } = customerId ? await admin.from("quotations").select("*").eq("customer_id", customerId) : { data: [] };
  const { data: invoices } = customerId ? await admin.from("invoices").select("*").eq("customer_id", customerId) : { data: [] };
  const invoiceIds = (invoices || []).map((row) => row.id);
  const { data: invoiceLines } = invoiceIds.length ? await admin.from("invoice_lines").select("*").in("invoice_id", invoiceIds) : { data: [] };
  const { data: submissions } = invoiceIds.length ? await admin.from("payment_submissions").select("*").in("invoice_id", invoiceIds) : { data: [] };
  const submissionIds = (submissions || []).map((row) => row.id);
  const { data: collectionTransactions } = submissionIds.length ? await admin.from("payment_transactions").select("*").in("submission_id", submissionIds) : { data: [] };
  let transactions = collectionTransactions || [];
  let transactionIds = transactions.map((row) => row.id);
  const { data: allocations } = transactionIds.length ? await admin.from("payment_allocations").select("*").in("transaction_id", transactionIds) : { data: [] };
  const { data: subscriptions } = invoiceIds.length ? await admin.from("subscriptions").select("*").in("invoice_id", invoiceIds) : { data: [] };
  const subscriptionIds = (subscriptions || []).map((row) => row.id);
  const { data: plannedDays } = subscriptionIds.length ? await admin.from("planned_service_days").select("*").in("subscription_id", subscriptionIds) : { data: [] };
  const { data: revenueEntries } = subscriptionIds.length ? await admin.from("revenue_entries").select("*").in("subscription_id", subscriptionIds) : { data: [] };
  const { data: deferredEntries } = subscriptionIds.length ? await admin.from("deferred_revenue_entries").select("*").in("subscription_id", subscriptionIds) : { data: [] };
  const { data: refunds } = invoiceIds.length ? await admin.from("refunds").select("*").in("invoice_id", invoiceIds) : { data: [] };
  const refundIds = (refunds || []).map((row) => row.id);
  const refundTransactionIds = (refunds || []).map((row) => row.transaction_id).filter(Boolean) as string[];
  if (refundTransactionIds.length) {
    const { data: refundTransactions } = await admin.from("payment_transactions").select("*").in("id", refundTransactionIds);
    const knownTransactionIds = new Set(transactionIds);
    transactions = [...transactions, ...(refundTransactions || []).filter((row) => !knownTransactionIds.has(row.id))];
    transactionIds = transactions.map((row) => row.id);
  }
  const { data: commissions } = transactionIds.length || refundIds.length ? await admin.from("sales_commission_entries").select("*").or([transactionIds.length ? `source_transaction_id.in.(${transactionIds.join(",")})` : "", refundIds.length ? `refund_id.in.(${refundIds.join(",")})` : ""].filter(Boolean).join(",")) : { data: [] };
  const { data: targetActuals } = transactionIds.length ? await admin.from("sales_target_actuals").select("*").in("payment_transaction_id", transactionIds) : { data: [] };
  const organizationId = customer?.organization_id;
  const { data: domainEvents } = organizationId ? await admin.from("domain_events").select("*").eq("organization_id", organizationId).order("occurred_at") : { data: [] };
  const relatedIds = [customerId, ...(quotations || []).map((row) => row.id), ...invoiceIds, ...submissionIds, ...transactionIds, ...subscriptionIds, ...refundIds].filter(Boolean) as string[];
  const { data: auditLogs } = relatedIds.length ? await admin.from("audit_logs").select("id,action,entity_type,entity_id,actor_user_id,occurred_at").in("entity_id", relatedIds).order("occurred_at") : { data: [] };
  const evidence = { stage, capturedAt: new Date().toISOString(), customer, quotations, invoices, invoiceLines, submissions: (submissions || []).map(({ proof_reference: _proof, ...row }) => ({ ...row, proof_reference: _proof ? "[stored proof]" : null })), transactions, allocations, subscriptions, plannedDays, revenueEntries, deferredEntries, refunds, commissions, targetActuals, domainEvents: (domainEvents || []).filter((event) => relatedIds.includes(event.aggregate_id) || relatedIds.includes(String(event.payload?.invoice_id || ""))), auditLogs };
  await writeFile(join(evidenceDir, `${stage}.json`), JSON.stringify(evidence, null, 2));
  return evidence;
}

test.beforeAll(async () => { await mkdir(evidenceDir, { recursive: true }); });

test("real hosted commercial cycle through Sales, Finance and Operations UI", async ({ page }) => {
  await login(page, process.env.E2E_SALES_EMAIL!, process.env.E2E_SALES_PASSWORD!);
  await page.goto("/sales");
  await page.locator('input[name="customerName"]').fill(customerName);
  await page.locator('input[name="mobile"]').fill(customerMobile);
  await page.locator('select[name="packageVersionId"]').selectOption({ index: 1 });
  await page.locator('input[name="quantity"]').fill("1");
  await page.locator('input[name="discountPercent"]').fill("5");
  const validUntil = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
  await page.locator('input[name="validUntil"]').fill(validUntil);
  await page.getByRole("button", { name: "إنشاء العميل وعرض السعر" }).click();
  await expect(page.locator("tr").filter({ hasText: customerName }).first()).toBeVisible();
  await shot(page, "01-customer-quotation-issued");
  await snapshot("01-quotation-issued");

  let row = page.locator("tr").filter({ hasText: customerName });
  await row.getByRole("button", { name: "Accept" }).click();
  row = page.locator("tr").filter({ hasText: customerName });
  await expect(row.getByRole("button", { name: "Convert to Invoice" })).toBeVisible();
  await row.getByRole("button", { name: "Convert to Invoice" }).click();
  await expect(page).toHaveURL(/\/sales\/invoices\/[0-9a-f-]+/);
  const invoiceId = page.url().split("/").pop()!;
  await shot(page, "02-invoice-detail-printable");
  let state = await snapshot("02-invoice-created");
  const invoice = state.invoices?.find((item) => item.id === invoiceId);
  expect(invoice).toBeTruthy();

  await page.goto("/sales/invoices");
  await page.locator('select[name="invoiceId"]').selectOption(invoiceId);
  await page.locator('input[name="amount"]').fill("1000");
  await page.locator('input[name="externalReference"]').fill(`E2E-${Date.now()}-ONE`);
  await page.locator('input[name="proofFile"]').setInputFiles({ name: "payment-proof.png", mimeType: "image/png", buffer: proofPng });
  await page.getByRole("button", { name: "إرسال إلى Finance كـPending" }).click();
  await expect(page).toHaveURL(/saved=payment-pending/);
  await shot(page, "03-payment-proof-pending");
  state = await snapshot("03-before-finance-confirmation");
  expect(state.transactions).toHaveLength(0);

  await login(page, process.env.E2E_FINANCE_EMAIL!, process.env.E2E_FINANCE_PASSWORD!);
  await page.goto("/finance/payments");
  let paymentCard = page.locator("section.surface").filter({ hasText: customerName }).first();
  await expect(paymentCard.getByText("View Proof")).toBeVisible();
  await paymentCard.locator('input[aria-label="Confirmed amount"]').fill("500");
  await paymentCard.getByRole("button", { name: "Confirm Partial" }).click();
  await expect(page).toHaveURL(/saved=confirmed/);
  await shot(page, "04-finance-partial-confirmation");
  state = await snapshot("04-after-partial-confirmation");
  expect(state.invoices?.[0]?.status).toBe("partially_paid");
  expect(state.allocations).toHaveLength(1);
  expect(state.targetActuals).toHaveLength(1);
  expect(state.commissions?.length).toBeGreaterThan(0);

  const remaining = Number(state.invoices?.[0]?.total_amount) - Number(state.invoices?.[0]?.confirmed_paid_amount);
  await login(page, process.env.E2E_SALES_EMAIL!, process.env.E2E_SALES_PASSWORD!);
  await page.goto("/sales/invoices");
  await page.locator('select[name="invoiceId"]').selectOption(invoiceId);
  await page.locator('input[name="amount"]').fill(String(remaining));
  await page.locator('input[name="externalReference"]').fill(`E2E-${Date.now()}-TWO`);
  await page.locator('input[name="proofFile"]').setInputFiles({ name: "payment-proof-full.png", mimeType: "image/png", buffer: proofPng });
  await page.getByRole("button", { name: "إرسال إلى Finance كـPending" }).click();
  await expect(page).toHaveURL(/saved=payment-pending/);

  await login(page, process.env.E2E_FINANCE_EMAIL!, process.env.E2E_FINANCE_PASSWORD!);
  await page.goto("/finance/payments");
  paymentCard = page.locator("section.surface").filter({ hasText: customerName }).filter({ hasText: "pending" }).first();
  await paymentCard.getByRole("button", { name: "Confirm Full" }).click();
  await expect(page).toHaveURL(/saved=confirmed/);
  await shot(page, "05-finance-full-confirmation");
  state = await snapshot("05-after-full-confirmation");
  expect(state.invoices?.[0]?.status).toBe("paid");

  const packageVersionId = state.invoiceLines?.[0]?.package_version_id;
  await login(page, process.env.E2E_OPERATIONS_EMAIL!, process.env.E2E_OPERATIONS_PASSWORD!);
  await page.goto("/subscriptions");
  await page.locator('select[name="invoiceId"]').selectOption(invoiceId);
  await page.locator('select[name="packageVersionId"]').selectOption(packageVersionId);
  await page.locator('input[name="startsOn"]').fill(new Date().toISOString().slice(0, 10));
  await page.getByRole("button", { name: "تفعيل وإنشاء Deferred Revenue" }).click();
  await expect(page).toHaveURL(/saved=activated/);
  await shot(page, "06-subscription-activated");
  state = await snapshot("06-after-subscription-activation");
  expect(state.deferredEntries?.some((entry) => entry.entry_type === "activation")).toBe(true);

  await page.goto("/operations/subscribers");
  const dayRow = page.locator("tr").filter({ hasText: customerName }).filter({ hasText: "planned" }).first();
  await dayRow.getByRole("button", { name: "Confirm Delivered" }).click();
  await expect(page).toHaveURL(/saved=delivered/);
  await shot(page, "07-delivery-confirmed");
  state = await snapshot("07-after-delivery-confirmation");
  expect(state.plannedDays?.some((day) => day.status === "confirmed_delivered")).toBe(true);
  expect(state.revenueEntries?.length).toBeGreaterThan(0);

  await login(page, process.env.E2E_SALES_EMAIL!, process.env.E2E_SALES_PASSWORD!);
  await page.goto("/finance/payments");
  await page.locator('form[action] select[name="invoiceId"]').selectOption(invoiceId);
  await page.locator('select[name="subscriptionId"]').selectOption(state.subscriptions?.[0]?.id);
  await page.locator('input[name="amount"]').last().fill("100");
  await page.locator('input[name="reason"]').last().fill("Hosted E2E refund");
  await page.getByRole("button", { name: "إرسال للموافقة" }).click();
  await expect(page).toHaveURL(/saved=refund-requested/);
  await shot(page, "08-refund-requested");

  await login(page, process.env.E2E_FINANCE_EMAIL!, process.env.E2E_FINANCE_PASSWORD!);
  await page.goto("/finance/payments");
  let refundCard = page.locator("section.surface").filter({ hasText: "Hosted E2E refund" });
  await refundCard.getByRole("button", { name: "Approve" }).click();
  await expect(page).toHaveURL(/saved=refund-approved/);
  refundCard = page.locator("section.surface").filter({ hasText: "Hosted E2E refund" });
  await refundCard.locator('input[name="proofReference"]').fill("hosted-refund-proof");
  await refundCard.getByRole("button", { name: "Pay & Clawback" }).click();
  await expect(page).toHaveURL(/saved=refund-paid/);
  await shot(page, "09-refund-paid-clawback");
  state = await snapshot("09-after-refund-clawback");
  expect(state.transactions?.some((transaction) => transaction.transaction_type === "refund" && Number(transaction.amount) === -100)).toBe(true);
  expect(state.invoices?.[0]?.confirmed_paid_amount).toBe(5600);
  expect(state.invoices?.[0]?.status).toBe("partially_paid");
  expect(state.deferredEntries?.some((entry) => entry.entry_type === "refund" && Number(entry.deferred_delta) === -100)).toBe(true);
  expect(state.commissions?.some((commission) => commission.entry_type === "clawback")).toBe(true);
});
