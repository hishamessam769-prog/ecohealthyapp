"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { CheckCircle2, ChefHat, ClipboardCheck, LockKeyhole } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { HelpTip } from "@/components/help-tip";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { createClient } from "@/lib/supabase/client";
import type { ProductionRow } from "@/lib/domain";

const tomorrow=()=>new Date().toISOString().slice(0,10);
export default function KitchenPage(){
  const supabase=useMemo(()=>createClient(),[]); const [date,setDate]=useState(tomorrow()); const [rows,setRows]=useState<ProductionRow[]>([]); const [message,setMessage]=useState("");
  const load=useCallback(async()=>{const {data,error}=await supabase.from("production_queue").select("*").eq("production_date",date).order("delivery_zone").order("client_name_snapshot");if(error)setMessage(error.message);else setRows((data??[]) as ProductionRow[])},[date,supabase]); useEffect(()=>{void load()},[load]);
  const aggregate=Object.values(rows.reduce<Record<string,{key:string;meal:string;type:string;qty:number;lines:number}>>((a,r)=>{const k=`${r.meal_name_snapshot}|${r.meal_type}`;a[k]=a[k]?{...a[k],qty:a[k].qty+r.quantity,lines:a[k].lines+1}:{key:k,meal:r.meal_name_snapshot,type:r.meal_type,qty:r.quantity,lines:1};return a},{})); const done=rows.filter(r=>r.status==="approved_done").length;
  async function setStatus(id:string,status:"pending"|"in_prep"|"approved_done"){const {error}=await supabase.rpc("set_kitchen_status",{p_queue_id:id,p_status:status});setMessage(error?.message??(status==="approved_done"?"تم الاعتماد وإرسال Stop تلقائيًا للتوصيل":"تم تحديث الحالة"));if(!error)await load()}
  return <AppShell title="Kitchen Production" subtitle="Checklist للمطبخ مبني حرفيًا على Monthly Menu + Custom Overrides">
    {message?<div className="mb-4 rounded-md bg-blue-50 p-3 text-sm font-bold text-blue-900">{message}</div>:null}
    <div className="mb-4 grid gap-3 sm:grid-cols-3"><div className="flex items-center gap-3 rounded-lg bg-[#17211b] p-4 text-white"><LockKeyhole size={23}/><div><p className="text-xs text-white/70">Gatekeeper</p><p className="font-black">Accounting Confirmed Only</p></div></div><div className="rounded-lg border border-[#dce5df] bg-white p-4"><p className="text-xs text-[#66736b]">Production Lines</p><p className="mt-1 text-2xl font-black">{rows.length}</p></div><div className="rounded-lg border border-[#dce5df] bg-white p-4"><p className="text-xs text-[#66736b]">Approved</p><p className="mt-1 text-2xl font-black text-[#16794a]">{done}/{rows.length}</p></div></div>
    <div className="mb-4 flex flex-wrap items-center gap-2"><Input type="date" value={date} onChange={e=>setDate(e.target.value)} className="w-44"/><HelpTip text="غيّر التاريخ لرؤية Queue أي يوم. البيانات تأتي من Menu Planner وليس من قائمة ثابتة في الواجهة." /></div>
    <Tabs defaultValue="aggregate"><TabsList className="w-full sm:w-auto"><TabsTrigger value="aggregate" className="flex-1">الكميات المجمعة</TabsTrigger><TabsTrigger value="labels" className="flex-1">Client Labels</TabsTrigger></TabsList>
      <TabsContent value="aggregate"><div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">{aggregate.map(a=><Card key={a.key}><CardContent className="flex items-center gap-4 pt-5"><span className="flex size-14 items-center justify-center rounded-md bg-[#e5f5ec] text-[#16794a]"><ChefHat size={26}/></span><div><p className="text-3xl font-black">{a.qty}×</p><p className="font-black">{a.meal}</p><p className="mt-1 text-xs text-[#66736b]">{a.type} · {a.lines} عميل</p></div></CardContent></Card>)}</div>{aggregate.length===0?<p className="rounded-md bg-white p-8 text-center text-sm text-[#66736b]">لا توجد Queue لهذا التاريخ. أرسل المشتركين من Bulk Action أو أضف Ad-Hoc معتمد.</p>:null}</TabsContent>
      <TabsContent value="labels"><div className="space-y-3">{rows.map(r=><Card key={r.id} className={r.status==="approved_done"?"border-[#91c9a8] bg-[#f7fcf9]":""}><CardContent className="pt-5"><div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between"><div className="flex items-start gap-3"><span className="flex size-12 shrink-0 items-center justify-center rounded-md bg-[#eef4f0] text-[#16794a]">{r.status==="approved_done"?<CheckCircle2 size={24}/>:<ClipboardCheck size={24}/>}</span><div><div className="flex flex-wrap items-center gap-2"><h2 className="text-lg font-black">{r.client_name_snapshot}</h2><Badge>Zone {r.delivery_zone}</Badge><Badge variant="blue">{r.source}</Badge></div><p className="mt-1 font-bold">{r.quantity}× {r.meal_name_snapshot} · {r.meal_type}</p><p className="mt-1 text-sm text-[#66736b]">Diet: {r.dietary_notes_snapshot||"لا توجد ملاحظات"}</p></div></div><div className="grid grid-cols-3 gap-2 lg:min-w-[440px]"><Button size="lg" variant={r.status==="pending"?"default":"outline"} className="min-h-14" onClick={()=>setStatus(r.id,"pending")}>Pending</Button><Button size="lg" variant={r.status==="in_prep"?"default":"outline"} className="min-h-14" onClick={()=>setStatus(r.id,"in_prep")}>In Prep</Button><Button size="lg" variant={r.status==="approved_done"?"default":"outline"} className="min-h-14" onClick={()=>setStatus(r.id,"approved_done")}>Approved / Done</Button></div></div></CardContent></Card>)}</div></TabsContent>
    </Tabs>
  </AppShell>
}
