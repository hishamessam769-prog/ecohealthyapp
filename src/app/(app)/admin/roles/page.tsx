import { MinusCircle, Plus, ShieldOff } from "lucide-react";
import {
  createRoleAction,
  deactivateCustomRoleAction,
  grantRolePermissionAction,
  removeRolePermissionAction,
} from "@/app/actions/foundation";
import { ActionNotice } from "@/components/ui/action-notice";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requirePermission } from "@/lib/auth/require-permission";
import { getCustomRolePermissions, getPermissions, getRoles } from "@/lib/foundation/data";

export const metadata = { title: "الأدوار" };

const fieldClass = "mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3";

export default async function RolesPage({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string }> }) {
  const viewer = await requirePermission("roles.view");
  const [roles, permissions, mappings, query] = await Promise.all([
    getRoles(viewer),
    getPermissions(viewer),
    getCustomRolePermissions(viewer),
    searchParams,
  ]);
  const canManage = viewer.permissions.includes("roles.manage") && !viewer.preview;
  const activeCustomRoles = roles.filter((role) => !role.system && role.active);
  const grantablePermissions = permissions.filter((permission) => viewer.permissions.includes(permission.code));

  return <div className="space-y-7">
    <PageHeader eyebrow="Identity & access" title="الأدوار" description="إدارة أدوار مخصصة دون السماح للمدير بمنح صلاحية لا يملكها أو تصعيد دوره بنفسه." />
    <ActionNotice {...query} />

    {canManage ? <div className="grid gap-5 xl:grid-cols-2">
      <Card><CardHeader title="إنشاء دور مخصص" description="الأدوار النظامية لا تُعدل من هذه الشاشة." /><form action={createRoleAction} className="grid gap-4 p-5 sm:grid-cols-2">
        <label className="text-sm font-bold">اسم الدور *<input name="name" required className={fieldClass} /></label>
        <label className="text-sm font-bold">الرمز *<input name="code" required pattern="[a-z0-9_]+" className={fieldClass} placeholder="custom_role" /></label>
        <label className="text-sm font-bold sm:col-span-2">الوصف<input name="description" className={fieldClass} /></label>
        <Button type="submit" className="sm:col-span-2"><Plus size={18} />إنشاء الدور</Button>
      </form></Card>

      <Card><CardHeader title="إضافة صلاحية لدور مخصص" description="تظهر فقط الصلاحيات التي يمتلكها المنفذ بالفعل." /><form action={grantRolePermissionAction} className="grid gap-4 p-5 sm:grid-cols-2">
        <label className="text-sm font-bold">الدور المخصص *<select name="roleId" required className={fieldClass}><option value="">اختر</option>{activeCustomRoles.map((role) => <option key={role.id} value={role.id}>{role.name}</option>)}</select></label>
        <label className="text-sm font-bold">الصلاحية *<select name="permissionId" required className={fieldClass}><option value="">اختر</option>{grantablePermissions.map((permission) => <option key={permission.id} value={permission.id}>{permission.code}</option>)}</select></label>
        <Button type="submit" className="mt-auto sm:col-span-2">إضافة الصلاحية</Button>
      </form></Card>
    </div> : null}

    {canManage && activeCustomRoles.length ? <div className="grid gap-5 xl:grid-cols-2">
      <Card><CardHeader title="سحب صلاحية من دور مخصص" description="السحب فوري ويتطلب تأكيدًا ويُسجل في Audit Log." /><form action={removeRolePermissionAction} className="grid gap-4 p-5">
        <label className="text-sm font-bold">الدور والصلاحية *<select name="mapping" required className={fieldClass}><option value="">اختر</option>{mappings.map((mapping) => <option key={`${mapping.roleId}-${mapping.permissionId}`} value={`${mapping.roleId}:${mapping.permissionId}`}>{mapping.roleName} — {mapping.permissionCode}</option>)}</select></label>
        <label className="flex items-center gap-2 text-sm font-bold text-red-700"><input type="checkbox" name="confirm" value="yes" required />أؤكد سحب الصلاحية من الدور.</label>
        <Button type="submit" variant="danger"><MinusCircle size={18} />سحب الصلاحية</Button>
      </form></Card>

      <Card><CardHeader title="تعطيل دور مخصص" description="لا يحذف التاريخ، لكنه يوقف الصلاحيات الناتجة عن الدور فورًا." /><form action={deactivateCustomRoleAction} className="grid gap-4 p-5">
        <label className="text-sm font-bold">الدور *<select name="roleId" required className={fieldClass}><option value="">اختر</option>{activeCustomRoles.map((role) => <option key={role.id} value={role.id}>{role.name}</option>)}</select></label>
        <label className="flex items-center gap-2 text-sm font-bold text-red-700"><input type="checkbox" name="confirm" value="yes" required />أؤكد تعطيل الدور لكل المستخدمين الحاصلين عليه.</label>
        <Button type="submit" variant="danger"><ShieldOff size={18} />تعطيل الدور</Button>
      </form></Card>
    </div> : null}

    <Card><CardHeader title="دليل الأدوار" description={`${roles.length} دورًا متاحًا`} /><ResponsiveTable rows={roles} getKey={(row) => row.id} emptyTitle="لا توجد أدوار" emptyDescription="شغّل migrations وseed الأدوار النظامية." columns={[
      { key: "name", label: "الدور", primary: true, render: (row) => <div><strong>{row.name}</strong><span className="block font-mono text-xs font-normal text-[var(--text-muted)]">{row.code}</span></div> },
      { key: "type", label: "النوع", render: (row) => <Badge tone={row.system ? "info" : "neutral"}>{row.system ? "نظامي" : "مخصص"}</Badge> },
      { key: "status", label: "الحالة", render: (row) => <Badge tone={row.active ? "success" : "warning"}>{row.active ? "نشط" : "معطل"}</Badge> },
      { key: "description", label: "الوصف", render: (row) => row.description || "—" },
    ]} /></Card>
  </div>;
}
