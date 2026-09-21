import { Badge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requirePermission } from "@/lib/auth/require-permission";
import { getAuditEntries } from "@/lib/foundation/data";
import { formatDateTime } from "@/lib/utils";

export const metadata = { title: "سجل التدقيق" };

export default async function AuditLogPage() {
  const viewer = await requirePermission("audit.view");
  const entries = await getAuditEntries(viewer);
  return <div className="space-y-7"><PageHeader eyebrow="Governance" title="سجل التدقيق" description="سجل مركزي غير قابل للتعديل للمستخدم العادي. يعرض آخر 100 حدث ضمن نطاق المؤسسة." />
    <Card><CardHeader title="الأحداث الإدارية" description="سيضاف Old/New value للحقول الحساسة في وحداتها المختصة." /><ResponsiveTable rows={entries} getKey={(row) => row.id} emptyTitle="لا توجد أحداث مسجلة" emptyDescription="ستظهر هنا تغييرات المستخدمين والأدوار والفروع والإعدادات بعد تشغيلها." columns={[
      { key: "event", label: "الحدث", primary: true, render: (row) => <div><strong>{row.action}</strong><span className="block text-xs font-normal text-[var(--text-muted)]">{row.entityType}</span></div> },
      { key: "actor", label: "نفذه", render: (row) => row.actorName },
      { key: "reason", label: "السبب", render: (row) => row.reason || "—" },
      { key: "time", label: "الوقت", render: (row) => <Badge>{formatDateTime(row.createdAt, "ar")}</Badge> },
    ]} /></Card>
  </div>;
}
