import { Save } from "lucide-react";
import { saveSettingAction } from "@/app/actions/foundation";
import { ActionNotice } from "@/components/ui/action-notice";
import { Button } from "@/components/ui/button";
import { Card, CardHeader } from "@/components/ui/card";
import { PageHeader } from "@/components/ui/page-header";
import { requirePermission } from "@/lib/auth/require-permission";
import { getSettings } from "@/lib/foundation/data";

export const metadata = { title: "الإعدادات" };

export default async function SettingsPage({ searchParams }: { searchParams: Promise<{ saved?: string; error?: string }> }) {
  const viewer = await requirePermission("settings.view");
  const [settings, query] = await Promise.all([getSettings(viewer), searchParams]);
  const map = new Map(settings.map((item) => [item.key, item.value]));
  const canManage = viewer.permissions.includes("settings.manage") && !viewer.preview;
  return <div className="space-y-7"><PageHeader eyebrow="Configuration" title="إعدادات المؤسسة" description="قيم تشغيلية قابلة للتعديل دون hardcoding. السياسات المالية المؤثرة ستستخدم version history في وحداتها." /><ActionNotice {...query} />
    <div className="grid gap-5 lg:grid-cols-2">
      <Card><CardHeader title="المنطقة الزمنية" description="تخزن التواريخ كـUTC وتعرض وفق هذه المنطقة." /><form action={saveSettingAction} className="p-5"><input type="hidden" name="key" value="organization.timezone" /><label className="text-sm font-bold">Timezone<select name="value" defaultValue={map.get("organization.timezone") || "Africa/Cairo"} disabled={!canManage} className="mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3"><option value="Africa/Cairo">Africa/Cairo</option></select></label>{canManage ? <Button type="submit" className="mt-4"><Save size={17} />حفظ</Button> : null}</form></Card>
      <Card><CardHeader title="العملة الأساسية" description="كل معاملة مستقبلًا تحتفظ أيضًا برمز عملتها." /><form action={saveSettingAction} className="p-5"><input type="hidden" name="key" value="organization.base_currency" /><label className="text-sm font-bold">Currency<select name="value" defaultValue={map.get("organization.base_currency") || "EGP"} disabled={!canManage} className="mt-2 h-11 w-full rounded-xl border border-[var(--border)] bg-white px-3"><option value="EGP">EGP — Egyptian Pound</option></select></label>{canManage ? <Button type="submit" className="mt-4"><Save size={17} />حفظ</Button> : null}</form></Card>
    </div>
  </div>;
}
