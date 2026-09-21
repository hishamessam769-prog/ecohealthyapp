import { confirmDeliveryAction } from "@/app/actions/commercial";
import { ActionNotice } from "@/components/ui/action-notice";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requireAnyPermission } from "@/lib/auth/require-permission";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "عمليات المشتركين" };
type Day = { id: string; service_date: string; status: string; branch_id: string; subscriptions: { subscription_number: number; deferred_balance: number; customers: { full_name: string } | null; package_versions: { packages: { name: string } | null } | null } | null };

export default async function Page({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string }> }) {
  const viewer = await requireAnyPermission(["subscriptions.view", "service.confirm_delivery"]);
  const params = await searchParams;
  let days: Day[];
  if (viewer.preview) days = [
    { id: "88888888-8888-4888-8888-888888888888", service_date: "2026-09-17", status: "planned", branch_id: "preview-main", subscriptions: { subscription_number: 1402, deferred_balance: 5510, customers: { full_name: "أحمد محمد" }, package_versions: { packages: { name: "Eco 30" } } } },
    { id: "99999999-9999-4999-8999-999999999999", service_date: "2026-09-16", status: "confirmed_delivered", branch_id: "preview-main", subscriptions: { subscription_number: 1402, deferred_balance: 5510, customers: { full_name: "أحمد محمد" }, package_versions: { packages: { name: "Eco 30" } } } },
  ]; else {
    const supabase = await createClient();
    const { data } = await supabase.from("planned_service_days").select("id,service_date,status,branch_id,subscriptions(subscription_number,deferred_balance,customers(full_name),package_versions(packages(name)))").order("service_date", { ascending: true }).limit(100);
    days = (data || []) as unknown as Day[];
  }
  const canConfirm = viewer.preview || viewer.permissions.includes("service.confirm_delivery");
  return <div className="space-y-7">
    <PageHeader eyebrow="Daily operations" title="تأكيد أيام الخدمة" description="Confirm Delivered ينشئ Revenue Entry، يخفض Deferred Revenue، ويحوّل اليوم إلى confirmed_delivered نهائيًا." />
    <ActionNotice saved={params.saved} error={params.error} />
    <Card><CardHeader title="قائمة الخدمة" description="لا يتم الاعتراف بأي Revenue من planned أوdelivered_pending_confirmation." /><ResponsiveTable rows={days} getKey={(row) => row.id} emptyTitle="لا توجد أيام خدمة" emptyDescription="تُنشأ الأيام تلقائيًا عند تفعيل الاشتراك." columns={[
      { key: "date", label: "التاريخ", primary: true, render: (row: Day) => row.service_date },
      { key: "subscriber", label: "المشترك", render: (row: Day) => row.subscriptions?.customers?.full_name || "—" },
      { key: "subscription", label: "الاشتراك", render: (row: Day) => `SUB-${row.subscriptions?.subscription_number || "—"}` },
      { key: "package", label: "الباقة", render: (row: Day) => row.subscriptions?.package_versions?.packages?.name || "—" },
      { key: "deferred", label: "Deferred قبل التأكيد", render: (row: Day) => row.subscriptions?.deferred_balance ?? "—" },
      { key: "status", label: "الحالة", render: (row: Day) => <Badge tone={row.status === "confirmed_delivered" ? "success" : "warning"}>{row.status}</Badge> },
      { key: "action", label: "الإجراء", render: (row: Day) => canConfirm && ["planned", "delivered_pending_confirmation"].includes(row.status) ? <form action={confirmDeliveryAction}><input type="hidden" name="dayId" value={row.id} /><Button type="submit" size="sm">Confirm Delivered</Button></form> : <span className="text-xs text-[var(--text-muted)]">لا إجراء</span> },
    ]} /></Card>
  </div>;
}
