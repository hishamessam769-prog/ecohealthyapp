import { Badge } from "@/components/ui/badge";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requirePermission } from "@/lib/auth/require-permission";
import { getPermissions } from "@/lib/foundation/data";

export const metadata = { title: "الصلاحيات" };

export default async function PermissionsPage() {
  const viewer = await requirePermission("permissions.view");
  const permissions = await getPermissions(viewer);
  return <div className="space-y-7"><PageHeader eyebrow="Identity & access" title="قاموس الصلاحيات" description="أكواد ثابتة يربطها النظام بالأدوار؛ لا تعتمد الحماية على اسم الدور أو إخفاء زر في الواجهة." />
    <Card><CardHeader title="الصلاحيات المسجلة" description={`${permissions.length} صلاحية دقيقة`} /><ResponsiveTable rows={permissions} getKey={(row) => row.id} emptyTitle="لا توجد صلاحيات" emptyDescription="شغّل migration الأولى لإضافة قاموس الصلاحيات." columns={[
      { key: "name", label: "الصلاحية", primary: true, render: (row) => <div><strong>{row.name}</strong><span className="block font-mono text-xs font-normal text-[var(--text-muted)]">{row.code}</span></div> },
      { key: "module", label: "الوحدة", render: (row) => <Badge tone="neutral">{row.module}</Badge> },
      { key: "description", label: "الاستخدام", render: (row) => row.description || "—" },
    ]} /></Card>
  </div>;
}
