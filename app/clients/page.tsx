"use client";

import { useMemo, useState } from "react";
import { ExternalLink, MessageSquarePlus, Search } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { HelpTip } from "@/components/help-tip";
import { useERP } from "@/components/erp-provider";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";

export default function ClientsPage() {
  const { clients, subscriptions, addIssue } = useERP();
  const [search, setSearch] = useState("");
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [issueText, setIssueText] = useState("");
  const [imageUrl, setImageUrl] = useState("");

  const filtered = useMemo(() => clients.filter((client) => `${client.name} ${client.phone}`.toLowerCase().includes(search.toLowerCase())), [clients, search]);
  const selected = clients.find((client) => client.id === selectedId);

  function saveIssue() {
    if (!selectedId || !issueText.trim()) return;
    addIssue(selectedId, issueText, imageUrl);
    setIssueText("");
    setImageUrl("");
  }

  return (
    <AppShell title="العملاء CRM" subtitle="بيانات العميل، اشتراكاته، ومتابعة الشكاوى">
      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative w-full max-w-md">
          <Search className="absolute right-3 top-1/2 -translate-y-1/2 text-[#8a958e]" size={18} />
          <Input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="ابحث بالاسم أو الموبايل" className="pr-10" />
        </div>
        <div className="flex items-center text-sm font-semibold text-[#536158]">Issue Tracking <HelpTip text="سجل شكوى أو ملاحظة للعميل. النظام يحفظها بوقت التسجيل ويمكن إضافة رابط صورة اختياري." /></div>
      </div>

      <div className="grid gap-4 xl:grid-cols-2">
        {filtered.map((client) => {
          const clientSubs = subscriptions.filter((sub) => sub.clientId === client.id);
          const activeSubs = clientSubs.filter((sub) => sub.status === "Active" || sub.status === "Paused");
          return (
            <Card key={client.id}>
              <CardContent className="pt-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h2 className="text-lg font-bold text-[#17211b]">{client.name}</h2>
                    <p className="mt-1 text-sm text-[#66736b]" dir="ltr">{client.phone}</p>
                  </div>
                  <div className="flex gap-2"><Badge>Zone {client.zone}</Badge><Badge variant="blue">{activeSubs.length} اشتراك جاري</Badge></div>
                </div>

                <div className="mt-4 grid gap-2 rounded-md bg-[#f5f8f6] p-3 text-sm sm:grid-cols-2">
                  <p><span className="font-bold">ملاحظات الغذاء:</span> {client.dietaryNotes}</p>
                  <a href={client.locationUrl} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 font-bold text-[#16794a]">فتح الموقع <ExternalLink size={15} /></a>
                </div>

                <div className="mt-4">
                  <p className="mb-2 text-sm font-bold">الاشتراكات</p>
                  <div className="flex flex-wrap gap-2">
                    {clientSubs.map((sub) => <Badge key={sub.id} variant={sub.status === "Active" ? "default" : sub.status === "Paused" ? "orange" : "gray"}>{sub.program} · {sub.status}</Badge>)}
                    {clientSubs.length === 0 ? <span className="text-sm text-[#8a958e]">لا يوجد اشتراكات</span> : null}
                  </div>
                </div>

                <div className="mt-4 border-t border-[#e4ebe6] pt-4">
                  <div className="mb-2 flex items-center justify-between gap-2">
                    <p className="text-sm font-bold">سجل الملاحظات ({client.issues.length})</p>
                    <Button size="sm" variant="outline" onClick={() => setSelectedId(client.id)}><MessageSquarePlus size={16} /> تسجيل ملاحظة</Button>
                  </div>
                  {client.issues.slice(0, 2).map((issue) => (
                    <div key={issue.id} className="mb-2 rounded-md border border-[#e4ebe6] p-3 text-sm">
                      <p className="leading-6">{issue.text}</p>
                      <div className="mt-2 flex flex-wrap gap-3 text-xs text-[#7b867f]"><span>{issue.createdAt}</span>{issue.imageUrl ? <a href={issue.imageUrl} target="_blank" rel="noreferrer" className="font-bold text-[#16794a]">رابط الصورة</a> : null}</div>
                    </div>
                  ))}
                  {client.issues.length === 0 ? <p className="text-sm text-[#8a958e]">لا توجد شكاوى مسجلة.</p> : null}
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <Dialog open={Boolean(selectedId)} onOpenChange={(open) => !open && setSelectedId(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>تسجيل ملاحظة — {selected?.name}</DialogTitle>
            <DialogDescription>اكتب ما حدث بوضوح. الوقت يضاف تلقائيًا.</DialogDescription>
          </DialogHeader>
          <label className="mb-2 block text-sm font-bold">الملاحظة</label>
          <Textarea value={issueText} onChange={(event) => setIssueText(event.target.value)} placeholder="مثال: العميل طلب تقليل الملح" />
          <label className="mb-2 mt-4 block text-sm font-bold">رابط صورة (اختياري)</label>
          <Input value={imageUrl} onChange={(event) => setImageUrl(event.target.value)} placeholder="https://..." dir="ltr" />
          <Button className="mt-5 w-full" onClick={saveIssue} disabled={!issueText.trim()}>حفظ في سجل العميل</Button>
        </DialogContent>
      </Dialog>
    </AppShell>
  );
}
