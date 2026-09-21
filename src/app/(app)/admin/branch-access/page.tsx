import { Building2, Link2, Unlink } from "lucide-react";
import { assignBranchAccessAction, createBranchAction, revokeBranchAccessAction } from "@/app/actions/foundation";
import { ActionNotice } from "@/components/ui/action-notice";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requirePermission } from "@/lib/auth/require-permission";
import { getBranchAccess, getFoundationUsers } from "@/lib/foundation/data";

export const metadata = { title: "صلاحيات الفروع" };

export default async function BranchAccessPage({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string }> }) {
  const viewer = await requirePermission("branches.view");
  const [access, users, query] = await Promise.all([getBranchAccess(viewer), getFoundationUsers(viewer), searchParams]);
  const canManage = viewer.permissions.includes("branches.manage") && !viewer.preview;
  return <div className="space-y-7"><PageHeader eyebrow="Organization scope" title="الفروع ونطاق الوصول" description="الصلاحية تحدد ما يمكن فعله، ونطاق الفرع يحدد أين يمكن فعله. يجب نجاح الشرطين معًا." /><ActionNotice {...query} />
    {canManage ? <div className="grid gap-5 xl:grid-cols-2">
      <Card><CardHeader title="إنشاء فرع" description="الرمز فريد داخل المؤسسة ولا يتغير بعد استخدامه." /><form action={createBranchAction} className="grid gap-4 p-5 sm:grid-cols-[1fr_0.7fr_auto]"><label className="text-sm font-bold">اسم الفرع *<input name="name" required className="mt-2 h-11 w-full rounded-xl border border-[var(--border)] px-3" /></label><label className="text-sm font-bold">الرمز *<input name="code" required pattern="[a-z0-9_]+" className="mt-2 h-11 w-full rounded-xl border border-[var(--border)] px-3" /></label><Button type="submit" className="mt-auto"><Building2 size={18} />إضافة</Button></form></Card>
      <Card><CardHeader title="منح وصول لفرع" description="لا يمنح هذا الإجراء صلاحية وظيفية غير موجودة في دور المستخدم." /><form action={assignBranchAccessAction} className="grid gap-4 p-5 sm:grid-cols-2"><label className="text-sm font-bold">المستخدم *<select name="userId" required className="mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3"><option value="">اختر</option>{users.map((user) => <option key={user.id} value={user.id}>{user.name}</option>)}</select></label><label className="text-sm font-bold">الفرع *<select name="branchId" required className="mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3"><option value="">اختر</option>{viewer.branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name}</option>)}</select></label><label className="text-sm font-bold">مستوى الوصول<select name="accessLevel" className="mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3"><option value="view">عرض</option><option value="operate">تشغيل</option><option value="manage">إدارة</option></select></label><Button type="submit" className="mt-auto"><Link2 size={18} />منح الوصول</Button></form></Card>
      <Card><CardHeader title="سحب وصول فرع" description="السحب فوري ويتطلب تأكيدًا ويُسجل في Audit Log." /><form action={revokeBranchAccessAction} className="grid gap-4 p-5"><label className="text-sm font-bold">الوصول الحالي *<select name="accessId" required className="mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3"><option value="">اختر</option>{access.map((item) => <option key={item.id} value={item.id}>{item.userName} — {item.branchName} — {item.accessLevel}</option>)}</select></label><label className="flex items-center gap-2 text-sm font-bold text-red-700"><input type="checkbox" name="confirm" value="yes" required />أؤكد سحب وصول المستخدم إلى هذا الفرع.</label><Button type="submit" variant="danger"><Unlink size={18} />سحب الوصول</Button></form></Card>
    </div> : null}
    <Card><CardHeader title="الوصول الحالي" description={`${access.length} علاقة مستخدم بفرع`} /><ResponsiveTable rows={access} getKey={(row) => row.id} emptyTitle="لا توجد صلاحيات فروع" emptyDescription="أنشئ فرعًا ثم امنح المستخدمين النطاق المطلوب." columns={[
      { key: "user", label: "المستخدم", primary: true, render: (row) => row.userName },
      { key: "branch", label: "الفرع", render: (row) => row.branchName },
      { key: "level", label: "المستوى", render: (row) => <Badge tone={row.accessLevel === "manage" ? "info" : "neutral"}>{row.accessLevel}</Badge> },
      { key: "valid", label: "صالح حتى", render: (row) => row.validUntil || "مستمر" },
    ]} /></Card>
  </div>;
}
