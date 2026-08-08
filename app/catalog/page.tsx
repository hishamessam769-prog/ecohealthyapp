"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { CalendarDays, PackagePlus, Plus, Utensils } from "lucide-react";
import { AppShell } from "@/components/app-shell";
import { HelpTip } from "@/components/help-tip";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { createClient } from "@/lib/supabase/client";
import type { MealRow, MenuItemRow, PackageRow } from "@/lib/domain";

type MenuMonth = { id: string; month_start: string; name: string; status: "draft" | "published" | "archived" };
const monthKey = () => new Date().toISOString().slice(0, 7);

export default function CatalogPage() {
  const [meals,setMeals]=useState<MealRow[]>([]); const [packages,setPackages]=useState<PackageRow[]>([]); const [months,setMonths]=useState<MenuMonth[]>([]); const [items,setItems]=useState<MenuItemRow[]>([]);
  const [selectedMonth,setSelectedMonth]=useState(monthKey()); const [message,setMessage]=useState("");
  const [mealName,setMealName]=useState(""); const [mealType,setMealType]=useState("standard");
  const [packageName,setPackageName]=useState(""); const [sizeName,setSizeName]=useState("Regular"); const [days,setDays]=useState("6"); const [price,setPrice]=useState("");
  const [menuDate,setMenuDate]=useState(`${monthKey()}-01`); const [menuPackage,setMenuPackage]=useState(""); const [menuMeal,setMenuMeal]=useState(""); const [qty,setQty]=useState("1");
  const supabase=useMemo(()=>createClient(),[]);

  const load=useCallback(async()=>{
    const [m,p,mm]=await Promise.all([
      supabase.from("meals").select("id,name,meal_type,active").order("name"),
      supabase.from("packages").select("id,name,size_name,number_of_days,price,active").order("name"),
      supabase.from("menu_months").select("id,month_start,name,status").order("month_start",{ascending:false}),
    ]);
    setMeals((m.data??[]) as MealRow[]); setPackages((p.data??[]) as PackageRow[]); setMonths((mm.data??[]) as MenuMonth[]);
    const month= (mm.data??[]).find((x:any)=>x.month_start.startsWith(selectedMonth));
    if(month){const mi=await supabase.from("menu_calendar_items").select("id,service_date,package_id,meal_id,quantity,meals(name,meal_type),packages(name,size_name)").eq("menu_month_id",month.id).order("service_date");setItems((mi.data??[]) as unknown as MenuItemRow[])} else setItems([]);
  },[selectedMonth,supabase]);
  useEffect(()=>{void load()},[load]);
  useEffect(()=>{setMenuDate(`${selectedMonth}-01`)},[selectedMonth]);
  const currentMonth=months.find((m)=>m.month_start.startsWith(selectedMonth));

  async function addMeal(){if(!mealName.trim())return;const {error}=await supabase.from("meals").insert({name:mealName.trim(),meal_type:mealType});setMessage(error?.message??"تمت إضافة الوجبة");setMealName("");await load()}
  async function addPackage(){if(!packageName.trim()||!price)return;const {error}=await supabase.from("packages").insert({name:packageName.trim(),size_name:sizeName.trim()||"Regular",number_of_days:Number(days),price:Number(price)});setMessage(error?.message??"تمت إضافة الباكدج");setPackageName("");setPrice("");await load()}
  async function ensureMonth(){const start=`${selectedMonth}-01`;const {error}=await supabase.from("menu_months").insert({month_start:start,name:`Menu ${selectedMonth}`});setMessage(error?.message??"تم إنشاء منيو الشهر");await load()}
  async function publish(){if(!currentMonth)return;const {error}=await supabase.from("menu_months").update({status:"published",published_at:new Date().toISOString()}).eq("id",currentMonth.id);setMessage(error?.message??"تم نشر منيو الشهر — جاهز للقراءة الآلية");await load()}
  async function addMapping(){if(!currentMonth||!menuPackage||!menuMeal)return;const {error}=await supabase.from("menu_calendar_items").insert({menu_month_id:currentMonth.id,service_date:menuDate,package_id:menuPackage,meal_id:menuMeal,quantity:Number(qty)});setMessage(error?.message??"تم ربط اليوم بالوجبة");await load()}

  return <AppShell title="المنتجات ومنيو الشهر" subtitle="هنا يتحدد ما سيقرأه النظام تلقائيًا لكل اشتراك">
    {message?<div className="mb-4 rounded-md bg-blue-50 p-3 text-sm font-bold text-blue-800">{message}</div>:null}
    <Tabs defaultValue="menu"><TabsList className="w-full sm:w-auto"><TabsTrigger value="menu" className="flex-1">منيو الشهر</TabsTrigger><TabsTrigger value="packages" className="flex-1">الباكدجات</TabsTrigger><TabsTrigger value="meals" className="flex-1">الوجبات</TabsTrigger></TabsList>
      <TabsContent value="menu">
        <Card><CardHeader><div className="flex flex-wrap items-center justify-between gap-3"><div><CardTitle className="flex items-center gap-2"><CalendarDays size={21}/>Monthly Menu Planner <HelpTip text="كل صف يربط تاريخًا وباكدج بوجبة. عند إرسال الاشتراك للمطبخ يقرأ النظام هذا الجدول تلقائيًا." /></CardTitle></div><div className="flex gap-2"><Input type="month" value={selectedMonth} onChange={e=>setSelectedMonth(e.target.value)} className="w-40"/>{currentMonth?<Badge variant={currentMonth.status==="published"?"default":"blue"}>{currentMonth.status}</Badge>:null}</div></div></CardHeader><CardContent>
          {!currentMonth?<div className="rounded-md border border-dashed border-[#bfcac2] p-6 text-center"><p className="font-bold">لا يوجد Menu لهذا الشهر</p><Button className="mt-3" onClick={ensureMonth}>إنشاء منيو {selectedMonth}</Button></div>:<>
            <div className="grid gap-2 rounded-lg bg-[#f5f8f6] p-3 sm:grid-cols-5"><Input type="date" value={menuDate} onChange={e=>setMenuDate(e.target.value)}/><select value={menuPackage} onChange={e=>setMenuPackage(e.target.value)} className="min-h-11 rounded-md border border-[#cfdad3] bg-white px-3 text-sm"><option value="">اختر الباكدج</option>{packages.filter(p=>p.active).map(p=><option key={p.id} value={p.id}>{p.name} · {p.size_name}</option>)}</select><select value={menuMeal} onChange={e=>setMenuMeal(e.target.value)} className="min-h-11 rounded-md border border-[#cfdad3] bg-white px-3 text-sm"><option value="">اختر الوجبة</option>{meals.filter(m=>m.active).map(m=><option key={m.id} value={m.id}>{m.name}</option>)}</select><Input type="number" min="1" value={qty} onChange={e=>setQty(e.target.value)} placeholder="الكمية"/><Button onClick={addMapping}><Plus size={17}/>إضافة لليوم</Button></div>
            <div className="mt-4 overflow-x-auto"><table className="w-full min-w-[700px] text-right text-sm"><thead><tr className="border-b bg-[#f4f7f5] text-[#5d6961]"><th className="p-3">اليوم</th><th className="p-3">التاريخ</th><th className="p-3">الباكدج</th><th className="p-3">الوجبة</th><th className="p-3">الكمية</th></tr></thead><tbody>{items.map(i=><tr key={i.id} className="border-b border-[#e8eee9]"><td className="p-3 font-black">Day {Number(i.service_date.slice(8,10))}</td><td className="p-3">{i.service_date}</td><td className="p-3">{i.packages?.name} · {i.packages?.size_name}</td><td className="p-3 font-bold">{i.meals?.name}</td><td className="p-3">{i.quantity}</td></tr>)}</tbody></table></div>
            <div className="mt-4 flex justify-end"><Button onClick={publish} disabled={items.length===0||currentMonth.status==="published"}>{currentMonth.status==="published"?"المنيو منشور":"نشر واعتماد المنيو"}</Button></div>
          </>}
        </CardContent></Card>
      </TabsContent>
      <TabsContent value="packages"><div className="grid gap-4 xl:grid-cols-[380px_1fr]"><Card><CardHeader><CardTitle className="flex items-center gap-2"><PackagePlus size={20}/>باكدج جديد</CardTitle></CardHeader><CardContent className="space-y-3"><Input value={packageName} onChange={e=>setPackageName(e.target.value)} placeholder="Package A / Full Day"/><Input value={sizeName} onChange={e=>setSizeName(e.target.value)} placeholder="Regular / Hero"/><Input type="number" value={days} onChange={e=>setDays(e.target.value)} placeholder="عدد الأيام"/><Input type="number" value={price} onChange={e=>setPrice(e.target.value)} placeholder="السعر بالجنيه"/><Button className="w-full" onClick={addPackage}>حفظ الباكدج</Button></CardContent></Card><div className="grid gap-3 sm:grid-cols-2">{packages.map(p=><Card key={p.id}><CardContent className="pt-5"><p className="font-black">{p.name}</p><p className="mt-1 text-sm text-[#66736b]">{p.size_name} · {p.number_of_days} يوم</p><p className="mt-3 text-xl font-black text-[#16794a]">{Number(p.price).toLocaleString("ar-EG")} ج</p></CardContent></Card>)}</div></div></TabsContent>
      <TabsContent value="meals"><div className="grid gap-4 xl:grid-cols-[380px_1fr]"><Card><CardHeader><CardTitle className="flex items-center gap-2"><Utensils size={20}/>وجبة جديدة</CardTitle></CardHeader><CardContent className="space-y-3"><Input value={mealName} onChange={e=>setMealName(e.target.value)} placeholder="اسم الوجبة"/><select value={mealType} onChange={e=>setMealType(e.target.value)} className="min-h-11 w-full rounded-md border border-[#cfdad3] bg-white px-3 text-sm"><option value="standard">Standard</option><option value="lc">LC</option><option value="high_protein">High Protein</option></select><Button className="w-full" onClick={addMeal}>حفظ الوجبة</Button></CardContent></Card><div className="grid gap-3 sm:grid-cols-2">{meals.map(m=><Card key={m.id}><CardContent className="pt-5"><p className="font-black">{m.name}</p><Badge className="mt-2" variant={m.meal_type==="lc"?"blue":"gray"}>{m.meal_type}</Badge></CardContent></Card>)}</div></div></TabsContent>
    </Tabs>
  </AppShell>;
}
