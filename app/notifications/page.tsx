"use client";

import { Bell, CheckCheck, CircleDollarSign, ChefHat, TrendingUp } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { useERP } from "@/components/erp-provider";
import { HelpTip } from "@/components/help-tip";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

const iconByType = { kitchen: ChefHat, accounting: CircleDollarSign, sales: TrendingUp, system: Bell };

export default function NotificationsPage() {
  const { role, notifications, markNotificationRead, markAllNotificationsRead } = useERP();
  const visible = notifications.filter((item) => role === "admin" || item.role === role);
  const unread = visible.filter((item) => !item.read).length;

  return (
    <AppShell title="التنبيهات الذكية" subtitle="كل قسم يرى التنبيهات التي تحتاج تصرفًا منه">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2"><Badge variant={unread ? "red" : "default"}>{unread} غير مقروء</Badge><HelpTip text="التنبيهات تظهر تلقائيًا حسب الحدث: VIP بعد Cut-off للمطبخ، التحصيل للحسابات، وباقي 3 أيام أو أقل للمبيعات." /></div>
        <Button variant="outline" onClick={markAllNotificationsRead} disabled={unread === 0}><CheckCheck size={18} /> تحديد الكل كمقروء</Button>
      </div>

      <div className="space-y-3">
        {visible.map((item) => {
          const Icon = iconByType[item.type];
          return (
            <Card key={item.id} className={!item.read ? "border-[#9ac9ae] bg-[#f7fcf9]" : ""}>
              <CardContent className="pt-5">
                <div className="flex items-start gap-3">
                  <div className={`flex size-11 shrink-0 items-center justify-center rounded-md ${item.read ? "bg-slate-100 text-slate-600" : "bg-[#e5f5ec] text-[#16794a]"}`}><Icon size={22} /></div>
                  <div className="min-w-0 flex-1"><div className="flex flex-wrap items-center gap-2"><p className="font-bold">{item.title}</p><Badge variant="gray">{item.role}</Badge>{!item.read ? <Badge>جديد</Badge> : null}</div><p className="mt-1 text-sm leading-6 text-[#536158]">{item.body}</p><p className="mt-2 text-xs text-[#8a958e]">{item.createdAt}</p></div>
                  {!item.read ? <Button size="sm" variant="outline" onClick={() => markNotificationRead(item.id)}>تمت القراءة</Button> : null}
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </AppShell>
  );
}
