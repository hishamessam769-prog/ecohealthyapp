"use client";

import * as React from "react";
import { Bell, CheckCheck } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { HelpTip } from "@/components/help-tip";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { createClient } from "@/lib/supabase/client";

type NotificationRow = {
  id: string;
  title: string;
  body: string;
  read_at: string | null;
  created_at: string;
};

export default function NotificationsPage() {
  const [items, setItems] = React.useState<NotificationRow[]>([]);
  const [loading, setLoading] = React.useState(true);
  const supabase = React.useMemo(() => createClient(), []);

  const loadNotifications = React.useCallback(async () => {
    const { data } = await supabase
      .from("notifications")
      .select("id,title,body,read_at,created_at")
      .order("created_at", { ascending: false })
      .limit(100);
    setItems((data as NotificationRow[] | null) ?? []);
    setLoading(false);
  }, [supabase]);

  React.useEffect(() => {
    void loadNotifications();
  }, [loadNotifications]);

  async function markRead(id: string) {
    await supabase.from("notifications").update({ read_at: new Date().toISOString() }).eq("id", id);
    setItems((current) => current.map((item) => item.id === id ? { ...item, read_at: new Date().toISOString() } : item));
  }

  async function markAllRead() {
    const now = new Date().toISOString();
    await supabase.from("notifications").update({ read_at: now }).is("read_at", null);
    setItems((current) => current.map((item) => ({ ...item, read_at: item.read_at ?? now })));
  }

  const unread = items.filter((item) => !item.read_at).length;

  return (
    <AppShell title="التنبيهات" subtitle="تنبيهات المطبخ والحسابات والمبيعات حسب صلاحيتك">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Badge variant={unread ? "red" : "gray"}>{unread} غير مقروء</Badge>
          <HelpTip text="التنبيهات تظهر حسب صلاحية حسابك، مثل تحصيل الكاش أو قرب انتهاء الاشتراك." />
        </div>
        <Button variant="outline" onClick={markAllRead} disabled={unread === 0}>
          <CheckCheck size={18} /> تحديد الكل كمقروء
        </Button>
      </div>

      <div className="space-y-3">
        {loading ? <p className="text-sm text-[#66736b]">جاري تحميل التنبيهات...</p> : null}
        {!loading && items.length === 0 ? (
          <Card><CardContent className="flex items-center gap-3 py-6 text-sm text-[#66736b]"><Bell size={20} />لا توجد تنبيهات حاليًا.</CardContent></Card>
        ) : null}
        {items.map((item) => (
          <Card key={item.id} className={!item.read_at ? "border-[#9ac9ae] bg-[#f7fcf9]" : ""}>
            <CardContent className="flex items-start gap-3 py-5">
              <div className={`flex size-11 shrink-0 items-center justify-center rounded-md ${item.read_at ? "bg-slate-100 text-slate-600" : "bg-[#e5f5ec] text-[#16794a]"}`}><Bell size={21} /></div>
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2"><p className="font-bold">{item.title}</p>{!item.read_at ? <Badge>جديد</Badge> : null}</div>
                <p className="mt-1 text-sm leading-6 text-[#536158]">{item.body}</p>
                <p className="mt-2 text-xs text-[#8a958e]">{new Date(item.created_at).toLocaleString("ar-EG", { timeZone: "Africa/Cairo" })}</p>
              </div>
              {!item.read_at ? <Button size="sm" variant="outline" onClick={() => markRead(item.id)}>تمت القراءة</Button> : null}
            </CardContent>
          </Card>
        ))}
      </div>
    </AppShell>
  );
}
