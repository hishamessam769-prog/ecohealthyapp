import { ShieldMinus, UserCheck, UserPlus, UserX } from "lucide-react";
import {
  assignUserRoleAction,
  inviteUserAction,
  revokeUserRoleAction,
  setUserSuspensionAction,
} from "@/app/actions/foundation";
import { ActionNotice } from "@/components/ui/action-notice";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { ResponsiveTable } from "@/components/ui/responsive-table";
import { requirePermission } from "@/lib/auth/require-permission";
import { getFoundationUsers, getRoles, getUserRoleAssignments } from "@/lib/foundation/data";
import { formatDateTime } from "@/lib/utils";

export const metadata = { title: "المستخدمون" };

const fieldClass = "mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3";

export default async function UsersPage({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string }> }) {
  const viewer = await requirePermission("users.view");
  const [users, roles, assignments, query] = await Promise.all([
    getFoundationUsers(viewer),
    getRoles(viewer),
    getUserRoleAssignments(viewer),
    searchParams,
  ]);
  const canInvite = viewer.permissions.includes("users.manage") && !viewer.preview;
  const canAssign = viewer.permissions.includes("roles.assign") && !viewer.preview;
  const canSuspend = viewer.permissions.includes("users.suspend") && !viewer.preview;
  const assignableUsers = users.filter((user) => user.id !== viewer.id);
  const activeRoles = roles.filter((role) => role.active);
  const revocableAssignments = assignments.filter((assignment) => assignment.userId !== viewer.id);

  return <div className="space-y-7">
    <PageHeader eyebrow="Identity & access" title="المستخدمون" description="دعوة الموظفين وإدارة حالتهم وأدوارهم مع منع التصعيد الذاتي وتسجيل كل تغيير." />
    <ActionNotice {...query} />

    {canInvite || canAssign ? <div className="grid gap-5 xl:grid-cols-2">
      {canInvite ? <Card>
        <CardHeader title="دعوة مستخدم" description="إسناد الدور الأولي لا يظهر ولا يُقبل إلا عند امتلاك roles.assign." />
        <form action={inviteUserAction} className="grid gap-4 p-5 sm:grid-cols-2">
          <label className="text-sm font-bold">الاسم الكامل *<input name="fullName" required minLength={2} className={fieldClass} /></label>
          <label className="text-sm font-bold">البريد الإلكتروني *<input name="email" type="email" required className={fieldClass} /></label>
          {canAssign ? <label className="text-sm font-bold">الدور الأولي
            <select name="roleId" className={fieldClass}><option value="">بدون دور</option>{activeRoles.map((role) => <option key={role.id} value={role.id}>{role.name}</option>)}</select>
          </label> : null}
          <Button type="submit" className="mt-auto"><UserPlus size={18} />إرسال الدعوة</Button>
        </form>
      </Card> : null}

      {canAssign ? <Card>
        <CardHeader title="إسناد دور" description="لا يمكن الإسناد للنفس أو منح صلاحيات أعلى من صلاحيات المنفذ." />
        <form action={assignUserRoleAction} className="grid gap-4 p-5 sm:grid-cols-2">
          <label className="text-sm font-bold">المستخدم *<select name="userId" required className={fieldClass}><option value="">اختر</option>{assignableUsers.map((user) => <option key={user.id} value={user.id}>{user.name}</option>)}</select></label>
          <label className="text-sm font-bold">الدور *<select name="roleId" required className={fieldClass}><option value="">اختر</option>{activeRoles.map((role) => <option key={role.id} value={role.id}>{role.name}</option>)}</select></label>
          <Button type="submit" className="sm:col-span-2">إسناد الدور</Button>
        </form>
      </Card> : null}
    </div> : null}

    {canAssign || canSuspend ? <div className="grid gap-5 xl:grid-cols-2">
      {canAssign ? <Card>
        <CardHeader title="سحب دور" description="السحب فوري ويتطلب تأكيدًا صريحًا ويظهر في Audit Log." />
        <form action={revokeUserRoleAction} className="grid gap-4 p-5">
          <label className="text-sm font-bold">الإسناد الحالي *<select name="assignmentId" required className={fieldClass}><option value="">اختر</option>{revocableAssignments.map((assignment) => <option key={assignment.id} value={assignment.id}>{assignment.userName} — {assignment.roleName}</option>)}</select></label>
          <label className="flex items-center gap-2 text-sm font-bold text-red-700"><input type="checkbox" name="confirm" value="yes" required />أؤكد سحب الدور والصلاحيات الناتجة عنه.</label>
          <Button type="submit" variant="danger"><ShieldMinus size={18} />سحب الدور</Button>
        </form>
      </Card> : null}

      {canSuspend ? <Card>
        <CardHeader title="تعليق أو إعادة تفعيل مستخدم" description="المستخدم المعلق يُمنع من تسجيل الدخول والوصول إلى المؤسسة." />
        <form action={setUserSuspensionAction} className="grid gap-4 p-5 sm:grid-cols-2">
          <label className="text-sm font-bold">المستخدم *<select name="userId" required className={fieldClass}><option value="">اختر</option>{assignableUsers.map((user) => <option key={user.id} value={user.id}>{user.name} — {user.status}</option>)}</select></label>
          <label className="text-sm font-bold">الإجراء *<select name="operation" required className={fieldClass}><option value="suspend">تعليق</option><option value="reactivate">إعادة تفعيل</option></select></label>
          <label className="flex items-center gap-2 text-sm font-bold text-red-700 sm:col-span-2"><input type="checkbox" name="confirm" value="yes" required />أؤكد تغيير حالة دخول المستخدم.</label>
          <Button type="submit" variant="danger" className="sm:col-span-2"><UserX size={18} />تنفيذ تغيير الحالة</Button>
        </form>
      </Card> : null}
    </div> : null}

    <Card><CardHeader title="دليل المستخدمين" description={`${users.length} مستخدم داخل النطاق المسموح`} /><ResponsiveTable rows={users} getKey={(row) => row.id} emptyTitle="لا يوجد مستخدمون" emptyDescription="استخدم نموذج الدعوة بعد ربط Supabase." columns={[
      { key: "name", label: "المستخدم", primary: true, render: (row) => <div><strong>{row.name}</strong><span className="block text-xs font-normal text-[var(--text-muted)]">{row.email}</span></div> },
      { key: "roles", label: "الأدوار النشطة", render: (row) => row.roles.length ? row.roles.join("، ") : "—" },
      { key: "status", label: "الحالة", render: (row) => <Badge tone={row.status === "active" ? "success" : "warning"}>{row.status === "active" ? <span className="inline-flex items-center gap-1"><UserCheck size={13} />active</span> : row.status}</Badge> },
      { key: "created", label: "تاريخ الإضافة", render: (row) => formatDateTime(row.createdAt, "ar") },
    ]} /></Card>
  </div>;
}
