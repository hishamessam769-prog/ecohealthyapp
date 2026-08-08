"use client";

import { useState } from "react";
import { CheckCircle2, CreditCard, ExternalLink, FileCheck2, ShieldAlert } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { isFinanciallyBlocked, useERP } from "@/components/erp-provider";
import { HelpTip } from "@/components/help-tip";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";

export default function AccountingPage() {
  const { clients, subscriptions, cancellations, notifications, verifyPayment, reviewCancellation, confirmTransfer } = useERP();
  const [receipts, setReceipts] = useState<Record<string, string>>({});
  const payOnFirst = subscriptions.filter((item) => item.paymentType === "PayOnFirstDelivery");
  const blockedCount = payOnFirst.filter(isFinanciallyBlocked).length;
  const cashAlerts = notifications.filter((item) => item.role === "accounting" && item.title.includes("تحصيل نقدي") && !item.read).length;

  return (
    <AppShell title="الحسابات" subtitle="بوابة PayOnFirstDelivery، المصالحة، واعتماد Refund">
      <div className="mb-4 grid gap-3 sm:grid-cols-3">
        <div className="rounded-lg border border-red-200 bg-red-50 p-4"><p className="text-xs font-bold text-red-700">محظور ماليًا</p><p className="mt-1 text-3xl font-black text-red-900">{blockedCount}</p></div>
        <div className="rounded-lg border border-[#dce5df] bg-white p-4"><p className="text-xs text-[#66736b]">تنبيهات تحصيل Cash</p><p className="mt-1 text-3xl font-black">{cashAlerts}</p></div>
        <div className="rounded-lg border border-[#dce5df] bg-white p-4"><p className="text-xs text-[#66736b]">طلبات إلغاء مفتوحة</p><p className="mt-1 text-3xl font-black">{cancellations.filter((item) => item.status !== "Transferred").length}</p></div>
      </div>

      <Tabs defaultValue="gate">
        <TabsList className="w-full sm:w-auto"><TabsTrigger value="gate" className="flex-1 sm:flex-none">بوابة الدفع</TabsTrigger><TabsTrigger value="refunds" className="flex-1 sm:flex-none">الإلغاءات وRefund</TabsTrigger></TabsList>

        <TabsContent value="gate">
          <div className="mb-3 flex items-center gap-1 text-sm font-bold text-[#536158]">PayOnFirstDelivery Gatekeeper <HelpTip text="بعد أول تسليم، أي اشتراك لم يعتمد Accounting دفعه يصبح BLOCKED تلقائيًا فلا يدخل إنتاج أو توصيل جديد." /></div>
          <div className="space-y-3">
            {payOnFirst.map((sub) => {
              const client = clients.find((item) => item.id === sub.clientId);
              const blocked = isFinanciallyBlocked(sub);
              return (
                <Card key={sub.id} className={blocked ? "border-red-200" : ""}>
                  <CardContent className="pt-5">
                    <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                      <div className="flex items-start gap-3">
                        <div className={`flex size-11 shrink-0 items-center justify-center rounded-md ${blocked ? "bg-red-50 text-red-700" : "bg-[#e5f5ec] text-[#16794a]"}`}>{blocked ? <ShieldAlert size={23} /> : <CreditCard size={23} />}</div>
                        <div><div className="flex flex-wrap items-center gap-2"><p className="font-bold">{client?.name}</p>{blocked ? <Badge variant="red">BLOCKED</Badge> : sub.paymentVerified ? <Badge>Verified</Badge> : <Badge variant="blue">First Delivery Pending</Badge>}</div><p className="mt-1 text-sm text-[#66736b]">{sub.program} · {sub.totalPrice.toLocaleString("ar-EG")} ج · {sub.paymentType}</p></div>
                      </div>
                      <Button onClick={() => verifyPayment(sub.id)} disabled={sub.paymentVerified}><CheckCircle2 size={18} /> {sub.paymentVerified ? "الدفع مؤكد" : "تأكيد استلام الدفع"}</Button>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        </TabsContent>

        <TabsContent value="refunds">
          <div className="mb-3 flex items-center gap-1 text-sm font-bold text-[#536158]">معادلة الإلغاء الآلية <HelpTip text="Refund = Remaining Value − 20% من القيمة المستهلكة − 30 جنيهًا عن كل يوم توصيل مسجل. Accounting يراجع ثم يؤكد التحويل." /></div>
          <div className="space-y-4">
            {cancellations.map((request) => {
              const client = clients.find((item) => item.id === request.clientId);
              const receipt = receipts[request.id] ?? "";
              return (
                <Card key={request.id}>
                  <CardHeader><div className="flex flex-wrap items-center justify-between gap-2"><CardTitle>{client?.name} · Refund</CardTitle><Badge variant={request.status === "Transferred" ? "default" : request.status === "Reviewed" ? "blue" : "orange"}>{request.status}</Badge></div></CardHeader>
                  <CardContent>
                    <div className="grid gap-2 text-sm sm:grid-cols-2 lg:grid-cols-5">
                      <div className="rounded-md bg-[#f5f8f6] p-3"><p className="text-xs text-[#7a867e]">Remaining</p><p className="mt-1 font-bold">{request.remainingValue.toFixed(2)} ج</p></div>
                      <div className="rounded-md bg-[#f5f8f6] p-3"><p className="text-xs text-[#7a867e]">Consumed</p><p className="mt-1 font-bold">{request.consumedValue.toFixed(2)} ج</p></div>
                      <div className="rounded-md bg-red-50 p-3"><p className="text-xs text-red-700">20% Penalty</p><p className="mt-1 font-bold text-red-800">-{request.consumedPenalty.toFixed(2)} ج</p></div>
                      <div className="rounded-md bg-red-50 p-3"><p className="text-xs text-red-700">Delivery Penalty</p><p className="mt-1 font-bold text-red-800">-{request.deliveryPenalty.toFixed(2)} ج</p></div>
                      <div className="rounded-md bg-[#e5f5ec] p-3"><p className="text-xs text-[#0f603a]">Refund</p><p className="mt-1 text-lg font-black text-[#0f603a]">{request.refundAmount.toFixed(2)} ج</p></div>
                    </div>

                    <div className="mt-4 flex flex-col gap-2 sm:flex-row">
                      {request.status === "Requested" ? <Button onClick={() => reviewCancellation(request.id)}><FileCheck2 size={18} /> مراجعة واعتماد الحساب</Button> : null}
                      {request.status === "Reviewed" ? <><Input value={receipt} onChange={(event) => setReceipts((current) => ({ ...current, [request.id]: event.target.value }))} placeholder="رابط إيصال التحويل https://..." dir="ltr" /><Button onClick={() => confirmTransfer(request.id, receipt)} disabled={!receipt.trim()}><CheckCircle2 size={18} /> تأكيد التحويل</Button></> : null}
                      {request.status === "Transferred" && request.receiptUrl ? <a href={request.receiptUrl} target="_blank" rel="noreferrer" className="inline-flex min-h-11 items-center justify-center gap-2 rounded-md bg-[#e5f5ec] px-4 text-sm font-bold text-[#0f603a]">فتح إيصال التحويل <ExternalLink size={17} /></a> : null}
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        </TabsContent>
      </Tabs>
    </AppShell>
  );
}
