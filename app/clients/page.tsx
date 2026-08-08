"use client";

import Link from "next/link";
import { useCallback, useEffect, useMemo, useState } from "react";
import { ArrowUpDown, Plus, Search, UserRound } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { HelpTip } from "@/components/help-tip";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { createClient } from "@/lib/supabase/client";
import type { ClientSummaryRow } from "@/lib/domain";

type SortKey="revenue"|"cancellations"|"complaints";

export default function ClientsPage(){
  const supabase=useMemo(()=>createClient(),[]); const [clients,setClients]=useState<ClientSummaryRow[]>([]); const [search,setSearch]=useState(""); const [sort,setSort]=useState<SortKey>("revenue"); const [open,setOpen]=useState(false); const [message,setMessage]=useState("");
  const [name,setName]=useState(""); const [phone,setPhone]=useState(""); const [zone,setZone]=useState("1"); const [location,setLocation]=useState(""); const [address,setAddress]=useState(""); const [diet,setDiet]=useState("");
  const load=useCallback(async()=>{const {data,error}=await supabase.from("client_360_summary").select("*");if(error)setMessage(error.message);else setClients((data??[]) as ClientSummaryRow[])},[supabase]); useEffect(()=>{void load()},[load]);
  const shown=clients.filter(c=>`${c.full_name} ${c.phone}`.toLowerCase().includes(search.toLowerCase())).sort((a,b)=>sort==="revenue"?Number(b.total_verified_paid)-Number(a.total_verified_paid):sort==="cancellations"?b.total_cancellations-a.total_cancellations:b.total_complaints-a.total_complaints);
  async function addClient(){if(!name.trim()||!phone.trim())return;const {error}=await supabase.from("clients").insert({full_name:name.trim(),phone:phone.trim(),delivery_zone:Number(zone),location_url:location.trim()||null,address_text:address.trim()||null,dietary_notes:diet.trim()||null});if(error){setMessage(error.message);return}setOpen(false);setName("");setPhone("");setDiet("");setMessage("تم إنشاء العميل");await load()}

  return <AppShell title="Client 360" subtitle="كل ما يخص العميل ماليًا وتشغيليًا في مكان واحد">
    {message?<div className="mb-4 rounded-md bg-blue-50 p-3 text-sm font-bold text-blue-900">{message}</div>:null}
    <div className="mb-4 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between"><div className="relative w-full max-w-md"><Search size={18} className="absolute right-3 top-1/2 -translate-y-1/2 text-[#8a958e]"/><Input value={search} onChange={e=>setSearch(e.target.value)} placeholder="ابحث بالاسم أو الموبايل" className="pr-10"/></div><div className="flex flex-wrap gap-2"><div className="flex items-center gap-1"><ArrowUpDown size={17}/><HelpTip text="رتّب العملاء حسب أعلى إيراد أو أكثر إلغاءات أو أكثر شكاوى لتحديد الأولويات بسرعة." /></div>{([['revenue','أعلى إيراد'],['cancellations','أكثر إلغاءات'],['complaints','أكثر شكاوى']] as const).map(([k,l])=><Button key={k} size="sm" variant={sort===k?"default":"outline"} onClick={()=>setSort(k)}>{l}</Button>)}<Button size="sm" onClick={()=>setOpen(true)}><Plus size={16}/>عميل جديد</Button></div></div>
    <div className="grid gap-3 xl:grid-cols-2">{shown.map(c=><Link key={c.id} href={`/clients/${c.id}`}><Card className="h-full transition-colors hover:border-[#9ac8ac] hover:bg-[#fbfdfc]"><CardContent className="pt-5"><div className="flex items-start justify-between gap-3"><div className="flex items-center gap-3"><span className="flex size-11 items-center justify-center rounded-md bg-[#e5f5ec] text-[#16794a]"><UserRound size={22}/></span><div><h2 className="font-black">{c.full_name}</h2><p className="mt-1 text-sm text-[#66736b]" dir="ltr">{c.phone}</p></div></div><Badge>Zone {c.delivery_zone}</Badge></div><div className="mt-4 grid grid-cols-4 gap-2 text-center"><div className="rounded-md bg-[#f5f8f6] p-2"><p className="text-[10px] text-[#748078]">Paid</p><p className="mt-1 text-sm font-black">{Number(c.total_verified_paid).toLocaleString()}</p></div><div className="rounded-md bg-[#f5f8f6] p-2"><p className="text-[10px] text-[#748078]">Orders</p><p className="mt-1 text-sm font-black">{c.total_orders}</p></div><div className="rounded-md bg-[#f5f8f6] p-2"><p className="text-[10px] text-[#748078]">Complaints</p><p className="mt-1 text-sm font-black">{c.total_complaints}</p></div><div className="rounded-md bg-[#f5f8f6] p-2"><p className="text-[10px] text-[#748078]">Cancel</p><p className="mt-1 text-sm font-black">{c.total_cancellations}</p></div></div></CardContent></Card></Link>)}</div>
    <Dialog open={open} onOpenChange={setOpen}><DialogContent><DialogHeader><DialogTitle>عميل جديد</DialogTitle><DialogDescription>أدخل أقل قدر من البيانات المطلوبة للتشغيل.</DialogDescription></DialogHeader><div className="grid gap-3 sm:grid-cols-2"><Input value={name} onChange={e=>setName(e.target.value)} placeholder="الاسم"/><Input value={phone} onChange={e=>setPhone(e.target.value)} placeholder="الموبايل" dir="ltr"/><select value={zone} onChange={e=>setZone(e.target.value)} className="min-h-11 rounded-md border border-[#cfdad3] bg-white px-3"><option value="1">Zone 1</option><option value="2">Zone 2</option><option value="3">Zone 3</option><option value="4">Zone 4</option></select><Input value={location} onChange={e=>setLocation(e.target.value)} placeholder="Google Maps URL" dir="ltr"/><Input value={address} onChange={e=>setAddress(e.target.value)} placeholder="العنوان" className="sm:col-span-2"/><Textarea value={diet} onChange={e=>setDiet(e.target.value)} placeholder="Dietary Rules: ممنوع سمك، ممنوع تونة..." className="sm:col-span-2"/></div><Button className="mt-4 w-full" onClick={addClient}>حفظ العميل</Button></DialogContent></Dialog>
  </AppShell>
}
