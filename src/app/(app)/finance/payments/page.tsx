import { approveRefundAction, confirmPaymentAction, payRefundAction, rejectPaymentAction, requestRefundAction } from "@/app/actions/commercial";
import { ActionNotice } from "@/components/ui/action-notice";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { requireAnyPermission } from "@/lib/auth/require-permission";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "Finance Queue" };
const field = "mt-2 h-10 w-full rounded-xl border border-[var(--border)] bg-white px-3 text-sm";
type Submission = { id: string; submission_number: number; claimed_amount: number; confirmed_amount: number | null; currency: string; status: string; proof_reference: string; submitted_by: string; customers: { full_name: string } | null; invoices: { invoice_number: number; total_amount: number; confirmed_paid_amount: number } | null; profiles: { full_name: string } | null; proofUrl?: string };
type Refund = { id: string; amount: number; reason: string; status: string; requested_by: string; payment_proof_reference: string | null; invoices: { invoice_number: number } | null; customers: { full_name: string } | null };
type InvoiceOption = { id: string; invoice_number: number; total_amount: number; confirmed_paid_amount: number; customers: { full_name: string } | null };
type SubscriptionOption = { id: string; subscription_number: number; invoice_id: string };

export default async function Page({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string }> }) {
  const viewer = await requireAnyPermission(["payments.review", "payments.submit", "refunds.request", "refunds.approve"]);
  const params = await searchParams;
  let submissions: Submission[] = []; let refunds: Refund[] = []; let invoices: InvoiceOption[] = []; let subscriptions: SubscriptionOption[] = [];
  if (viewer.preview) {
    submissions = [{ id: "55555555-5555-4555-8555-555555555555", submission_number: 8833, claimed_amount: 4200, confirmed_amount: null, currency: "EGP", status: "pending", proof_reference: "https://example.invalid/proof.pdf", submitted_by: "sales-user", customers: { full_name: "نور خالد" }, invoices: { invoice_number: 2089, total_amount: 8400, confirmed_paid_amount: 0 }, profiles: { full_name: "مندوب المبيعات" }, proofUrl: "#" }];
    invoices = [{ id: "33333333-3333-4333-8333-333333333333", invoice_number: 2088, total_amount: 5700, confirmed_paid_amount: 5700, customers: { full_name: "أحمد محمد" } }];
    subscriptions = [{ id: "66666666-6666-4666-8666-666666666666", subscription_number: 1402, invoice_id: invoices[0].id }];
    refunds = [{ id: "77777777-7777-4777-8777-777777777777", amount: 500, reason: "إلغاء جزء من الخدمة", status: "requested", requested_by: "other-user", payment_proof_reference: null, invoices: { invoice_number: 2088 }, customers: { full_name: "أحمد محمد" } }];
  } else {
    const supabase = await createClient();
    const [submissionResult, refundResult, invoiceResult, subscriptionResult] = await Promise.all([
      supabase.from("payment_submissions").select("id,submission_number,claimed_amount,confirmed_amount,currency,status,proof_reference,submitted_by,customers(full_name),invoices!payment_submissions_invoice_id_fkey(invoice_number,total_amount,confirmed_paid_amount),profiles!payment_submissions_submitted_by_fkey(full_name)").order("submitted_at", { ascending: true }).limit(50),
      supabase.from("refunds").select("id,amount,reason,status,requested_by,payment_proof_reference,invoices(invoice_number),customers(full_name)").order("requested_at", { ascending: false }).limit(50),
      supabase.from("invoices").select("id,invoice_number,total_amount,confirmed_paid_amount,customers(full_name)").gt("confirmed_paid_amount", 0).order("issued_at", { ascending: false }),
      supabase.from("subscriptions").select("id,subscription_number,invoice_id").in("status", ["active", "frozen"]),
    ]);
    const loadError = submissionResult.error || refundResult.error || invoiceResult.error || subscriptionResult.error;
    if (loadError) throw new Error(`Finance Queue data load failed: ${loadError.message}`);
    const submissionRows = submissionResult.data;
    const refundRows = refundResult.data;
    const invoiceRows = invoiceResult.data;
    const subscriptionRows = subscriptionResult.data;
    submissions = (submissionRows || []) as unknown as Submission[];
    refunds = (refundRows || []) as unknown as Refund[];
    invoices = (invoiceRows || []) as unknown as InvoiceOption[];
    subscriptions = (subscriptionRows || []) as SubscriptionOption[];
    submissions = await Promise.all(submissions.map(async (submission) => {
      if (/^https:\/\//i.test(submission.proof_reference)) return { ...submission, proofUrl: submission.proof_reference };
      const { data } = await supabase.storage.from("erp-attachments").createSignedUrl(submission.proof_reference, 900);
      return { ...submission, proofUrl: data?.signedUrl };
    }));
  }
  const canConfirm = viewer.preview || viewer.permissions.includes("payments.confirm");
  const canReview = viewer.preview || viewer.permissions.includes("payments.review");
  const canRequestRefund = viewer.preview || viewer.permissions.includes("refunds.request");
  const canApproveRefund = viewer.preview || viewer.permissions.includes("refunds.approve");
  return <div className="space-y-7">
    <PageHeader eyebrow="Maker–Checker" title="Finance Queue" description="الإثبات Pending حتى يؤكده مستخدم Finance مختلف؛ Partial وFull وReject تنفذ RPCs فعلية." />
    <ActionNotice saved={params.saved} error={params.error} />
    <div className="grid gap-4 lg:grid-cols-2">{submissions.map((submission) => {
      const remaining = (submission.invoices?.total_amount || 0) - (submission.invoices?.confirmed_paid_amount || 0);
      const ownSubmission = submission.submitted_by === viewer.id;
      return <Card key={submission.id} className="p-5"><div className="flex items-start justify-between gap-3"><div><strong className="text-lg">PAY-{submission.submission_number}</strong><p className="text-sm text-[var(--text-muted)]">INV-{submission.invoices?.invoice_number} · {submission.customers?.full_name}</p></div><Badge tone={submission.status === "pending" ? "warning" : submission.status === "confirmed" ? "success" : "neutral"}>{submission.status}</Badge></div>
        <div className="mt-4 grid grid-cols-2 gap-3 rounded-xl bg-[var(--surface-muted)] p-4 text-sm"><span>المبلغ المدعى<strong className="block text-base">{submission.claimed_amount} {submission.currency}</strong></span><span>متبقي الفاتورة<strong className="block text-base">{remaining} {submission.currency}</strong></span><span>Submitted by<strong className="block">{submission.profiles?.full_name || "—"}</strong></span><span>Proof<strong className="block">{submission.proofUrl ? <a href={submission.proofUrl} target="_blank" rel="noreferrer" className="text-[var(--primary)] underline">View Proof</a> : "غير متاح"}</strong></span></div>
        {["pending", "under_review"].includes(submission.status) ? <div className="mt-4 space-y-3">{ownSubmission ? <p className="rounded-xl bg-amber-50 p-3 text-sm font-bold text-amber-800">لا يمكنك اعتماد الإثبات الذي أرسلته.</p> : null}{canConfirm && !ownSubmission ? <form action={confirmPaymentAction} className="grid gap-2 sm:grid-cols-[1fr_auto_auto]"><input type="hidden" name="submissionId" value={submission.id} /><input type="hidden" name="fullAmount" value={Math.min(submission.claimed_amount, remaining)} /><input aria-label="Confirmed amount" name="amount" type="number" min="0.01" max={Math.min(submission.claimed_amount, remaining)} step="0.01" defaultValue={Math.min(submission.claimed_amount, remaining)} required className="h-9 rounded-xl border border-[var(--border)] px-3 text-sm" /><Button type="submit" name="mode" value="partial" size="sm">Confirm Partial</Button><Button type="submit" name="mode" value="full" size="sm" variant="secondary">Confirm Full</Button></form> : null}{canReview && !ownSubmission ? <form action={rejectPaymentAction} className="grid gap-2 sm:grid-cols-[1fr_auto]"><input type="hidden" name="submissionId" value={submission.id} /><input name="reason" required minLength={3} placeholder="سبب الرفض الإلزامي" className="h-9 rounded-xl border border-[var(--border)] px-3 text-sm" /><Button type="submit" size="sm" variant="danger">Reject</Button></form> : null}</div> : null}
      </Card>;
    })}</div>
    {!submissions.length ? <Card className="p-6 text-center text-[var(--text-muted)]">لا توجد إثباتات دفع في الطابور.</Card> : null}
    {canRequestRefund ? <Card><CardHeader title="طلب Refund" description="المبلغ لا يتجاوز Confirmed Cash الصافي للفاتورة، والاشتراك—إن اختير—يجب أن يتبعها." /><form action={requestRefundAction} className="grid gap-4 p-5 md:grid-cols-2 xl:grid-cols-4"><label className="text-sm font-bold">الفاتورة *<select name="invoiceId" required className={field}><option value="">اختر</option>{invoices.map((invoice) => <option key={invoice.id} value={invoice.id}>INV-{invoice.invoice_number} · {invoice.customers?.full_name} · {invoice.confirmed_paid_amount}</option>)}</select></label><label className="text-sm font-bold">الاشتراك<select name="subscriptionId" className={field}><option value="">بدون</option>{subscriptions.map((subscription) => <option key={subscription.id} value={subscription.id}>SUB-{subscription.subscription_number}</option>)}</select></label><label className="text-sm font-bold">المبلغ *<input name="amount" type="number" min="0.01" step="0.01" required className={field} /></label><label className="text-sm font-bold">السبب *<input name="reason" minLength={3} required className={field} /></label><Button type="submit" className="md:col-span-2 xl:col-span-4">إرسال للموافقة</Button></form></Card> : null}
    <Card><CardHeader title="Refund Queue" description="Approval ثم Cash Reversal وCommission Clawback؛ الطالب لا يعتمد طلبه." /><div className="divide-y divide-[var(--border)]">{refunds.map((refund) => <div key={refund.id} className="grid gap-3 p-5 lg:grid-cols-[1fr_auto]"><div><div className="flex items-center gap-2"><strong>INV-{refund.invoices?.invoice_number} · {refund.customers?.full_name}</strong><Badge tone={refund.status === "paid" ? "success" : "warning"}>{refund.status}</Badge></div><p className="mt-1 text-sm text-[var(--text-muted)]">{refund.amount} EGP · {refund.reason}</p></div><div className="flex flex-wrap gap-2">{refund.status === "requested" && canApproveRefund && refund.requested_by !== viewer.id ? <form action={approveRefundAction}><input type="hidden" name="refundId" value={refund.id} /><Button type="submit" size="sm">Approve</Button></form> : null}{refund.status === "approved" && canApproveRefund && refund.requested_by !== viewer.id ? <form action={payRefundAction} className="flex gap-2"><input type="hidden" name="refundId" value={refund.id} /><input name="proofReference" required placeholder="مرجع الدفع" className="h-9 rounded-xl border border-[var(--border)] px-3 text-sm" /><Button type="submit" size="sm" variant="secondary">Pay & Clawback</Button></form> : null}</div></div>)}{!refunds.length ? <p className="p-5 text-sm text-[var(--text-muted)]">لا توجد طلبات استرداد.</p> : null}</div></Card>
  </div>;
}
