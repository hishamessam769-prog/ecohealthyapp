"use client";
import { Bell, CheckCheck } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { useERP } from "@/components/erp-provider";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";

export default function NotificationsPage(){const erp=useERP();const visible=erp.notifications.filter((x)=>erp.role==="admin"||x.role===erp.role);const unread=visible.filter((x)=>!x.read).length;return <AppShell title="التنبيهات الذكية" subtitle="المطبخ والحسابات والمبيعات يرون ما يحتاج تصرفًا">
  <div className="mb-4 flex items-center justify-between"><Badge variant={unread?"red":"default"}>{unread} غير مقروء</Badge><Button variant="outline" onClick={erp.markAllNotificationsRead} disabled={!unread}><CheckCheck size={17}/>قراءة الكل</Button></div>
  <div className="space-y-3">{visible.map((item)=><Card key={item.id} className={!item.read?"border-[#70ad89] bg-[#f7fcf9]":""}><CardContent className="flex items-start gap-3 pt-5"><span className={`flex size-11 shrink-0 items-center justify-center rounded ${item.read?"bg-slate-100":"bg-[#e8f6ee] text-[#16794a]"}`}><Bell size={21}/></span><div className="flex-1"><div className="flex flex-wrap items-center gap-2"><b>{item.title}</b><Badge variant="gray">{item.role}</Badge>{!item.read?<Badge>جديد</Badge>:null}</div><p className="mt-2 text-sm leading-6 text-[#536158]">{item.body}</p><small className="mt-2 block text-[#8a958e]">{item.createdAt}</small></div>{!item.read?<Button size="sm" variant="outline" onClick={()=>erp.markNotificationRead(item.id)}>تمت القراءة</Button>:null}</CardContent></Card>)}</div>
  </AppShell>}
