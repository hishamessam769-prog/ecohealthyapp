"use client";

import * as React from "react";
import { createClient as createSupabaseClient } from "@/lib/supabase/client";
import type {
  Cancellation, Client, Complaint, DeliveryStop, ERPState, FulfillmentDay, KitchenStatus,
  Meal, MenuEntry, NewClientInput, NewOrderInput, Notification, Order, Package, PaymentMethod,
  Reconciliation, Rider, Role, Subscription, Zone,
} from "@/lib/erp-types";

type Result = { ok: boolean; message: string; id?: string };
type ERPContextValue = ERPState & {
  role: Role; setRole: (role: Role) => void; demoMode: boolean; loading: boolean; error: string;
  resetDemo: () => void; purgeDemo: () => Promise<void>;
  addClient: (input: NewClientInput) => Promise<Result>;
  addComplaint: (clientId: string, category: string, details: string) => Promise<Result>;
  resolveComplaint: (id: string) => Promise<Result>;
  addMeal: (input: Omit<Meal, "id">) => Promise<Result>;
  addPackage: (input: Omit<Package, "id">) => Promise<Result>;
  upsertMenu: (date: string, slot: MenuEntry["slot"], mealId: string, notes?: string) => Promise<Result>;
  createOrder: (input: NewOrderInput) => Promise<Result>;
  verifyPayment: (paymentId: string) => Promise<Result>;
  rejectPayment: (paymentId: string) => Promise<Result>;
  pauseSubscription: (id: string, until?: string, indefinite?: boolean) => Promise<Result>;
  resumeSubscription: (id: string) => Promise<Result>;
  skipTomorrow: (id: string) => Promise<Result>;
  swapMeal: (fulfillmentId: string, mealId: string) => Promise<Result>;
  requestCancellation: (subscriptionId: string, reason: string) => Promise<Result>;
  reviewCancellation: (id: string) => Promise<Result>;
  transferCancellation: (id: string, receiptName: string) => Promise<Result>;
  sendToKitchen: (fulfillmentIds: string[]) => Promise<Result>;
  addEmergencyFulfillment: (date: string, clientId: string, mealId: string) => Promise<Result>;
  setKitchenStatus: (fulfillmentIds: string[], status: KitchenStatus) => Promise<Result>;
  assignRider: (date: string, zone: Zone, riderId: string) => Promise<Result>;
  setDeliveryStatus: (id: string, status: DeliveryStop["status"]) => Promise<Result>;
  collectCash: (id: string, amount: number, method: PaymentMethod) => Promise<Result>;
  closeReconciliation: (id: string, actualCash: number) => Promise<Result>;
  markNotificationRead: (id: string) => void; markAllNotificationsRead: () => void;
};

const ERPContext = React.createContext<ERPContextValue | null>(null);
const iso = (date: Date) => date.toISOString().slice(0, 10);
const today = () => iso(new Date());
const addDays = (value: string, amount: number) => { const d = new Date(`${value}T12:00:00`); d.setDate(d.getDate() + amount); return iso(d); };
const id = (prefix: string) => `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
const nowLabel = () => new Date().toLocaleString("ar-EG");

function monthlyMenu(meals: Meal[]): MenuEntry[] {
  const current = new Date();
  const year = current.getFullYear();
  const month = current.getMonth();
  const days = new Date(year, month + 1, 0).getDate();
  const slots: MenuEntry["slot"][] = ["Breakfast", "Lunch", "Dinner", "Snack"];
  const result: MenuEntry[] = [];
  for (let day = 1; day <= days; day += 1) {
    const date = iso(new Date(year, month, day, 12));
    for (const slot of slots) {
      const options = meals.filter((meal) => meal.slot === slot);
      if (options.length) result.push({ id: `menu-${date}-${slot}`, date, slot, mealId: options[(day - 1) % options.length].id });
    }
  }
  return result;
}

function makeDemoState(): ERPState {
  const meals: Meal[] = [
    { id: "meal-1", name: "Grilled Chicken & Rice", code: "L01", slot: "Lunch", regularCost: 92, heroCost: 146, active: true },
    { id: "meal-2", name: "Beef Kofta & Potatoes", code: "L02", slot: "Lunch", regularCost: 108, heroCost: 174, active: true },
    { id: "meal-3", name: "Chicken Fajita Wrap", code: "D01", slot: "Dinner", regularCost: 74, heroCost: 112, active: true },
    { id: "meal-4", name: "Omelette & Toast", code: "B01", slot: "Breakfast", regularCost: 49, heroCost: 72, active: true },
    { id: "meal-5", name: "Coconut Muffin", code: "S01", slot: "Snack", regularCost: 31, heroCost: 46, active: true },
    { id: "meal-6", name: "Steak & Cooked Vegetables", code: "L03", slot: "Lunch", regularCost: 148, heroCost: 229, active: true },
    { id: "meal-7", name: "Rumi Cheese Sandwich", code: "D02", slot: "Dinner", regularCost: 58, heroCost: 83, active: true },
  ];
  const packages: Package[] = [
    { id: "pkg-a", name: "Package A — Lunch", code: "PKG-A", days: 24, priceRegular: 4628, priceHero: 7380, mealSlots: ["Lunch"], active: true },
    { id: "pkg-b", name: "Package B — Full Day", code: "PKG-B", days: 24, priceRegular: 13883, priceHero: 18480, mealSlots: ["Breakfast", "Lunch", "Dinner", "Snack"], active: true },
    { id: "pkg-c", name: "Weekly Lunch", code: "WEEK-6", days: 6, priceRegular: 1999, priceHero: 3199, mealSlots: ["Lunch"], active: true },
  ];
  const clients: Client[] = [
    { id: "client-1", name: "أحمد علي", phone: "01090000001", email: "ahmed@example.com", zone: 1, address: "حدائق القبة، شارع مصر والسودان", locationUrl: "https://maps.google.com/?q=30.08,31.28", dietaryNotes: "تقليل الملح", strictExclusions: ["No fish", "No tuna"], preferences: ["Cooked vegetables", "Grilled chicken"], totalPaid: 4628, createdAt: today(), isDemo: true },
    { id: "client-2", name: "منة خالد", phone: "01090000002", zone: 2, address: "مدينة نصر، عباس العقاد", locationUrl: "https://maps.google.com/?q=30.05,31.34", dietaryNotes: "Low Carb", strictExclusions: ["No raw salads"], preferences: ["Steak", "Baladi bread"], totalPaid: 13883, createdAt: today(), isDemo: true },
    { id: "client-3", name: "كريم سمير", phone: "01090000003", zone: 3, address: "التجمع الخامس، النرجس", locationUrl: "https://maps.google.com/?q=30.01,31.44", dietaryNotes: "بدون صوص", strictExclusions: ["No dairy"], preferences: ["Chicken"], totalPaid: 0, createdAt: today(), isDemo: true },
    { id: "client-4", name: "داليا محمد", phone: "01090000004", zone: 4, address: "الشيخ زايد، الحي السابع", locationUrl: "https://maps.google.com/?q=30.03,30.98", dietaryNotes: "عميلة Weekly", strictExclusions: [], preferences: ["Rumi cheese"], totalPaid: 1999, createdAt: today(), isDemo: true },
  ];
  const orders: Order[] = [
    { id: "order-1", orderNumber: "ECO-260801", kind: "Subscription", clientId: "client-1", packageId: "pkg-a", size: "Regular", startDate: addDays(today(), -10), frequency: "Daily", totalDays: 24, amount: 4628, deliveryFees: 0, discount: 0, paymentMethod: "InstaPay", paymentStatus: "Verified", referenceId: "IP-884201", proofName: "instapay-ahmed.jpg", status: "Approved", salesRepId: "emp-sales", createdAt: addDays(today(), -12) },
    { id: "order-2", orderNumber: "ECO-260802", kind: "Subscription", clientId: "client-2", packageId: "pkg-b", size: "Regular", startDate: addDays(today(), -6), frequency: "Daily", totalDays: 24, amount: 13883, deliveryFees: 0, discount: 0, paymentMethod: "Website/App", paymentStatus: "Verified", referenceId: "WEB-99012", proofName: "web-order.png", status: "Approved", salesRepId: "emp-sales", createdAt: addDays(today(), -7) },
    { id: "order-3", orderNumber: "ECO-260803", kind: "Subscription", clientId: "client-3", packageId: "pkg-a", size: "Hero", startDate: addDays(today(), 1), frequency: "Daily", totalDays: 24, amount: 7380, deliveryFees: 0, discount: 0, paymentMethod: "Cash", paymentStatus: "Pending", status: "Pending Accounting", salesRepId: "emp-sales", createdAt: today() },
    { id: "order-4", orderNumber: "ECO-260804", kind: "AdHoc", clientId: "client-4", size: "Regular", startDate: addDays(today(), 1), deliveryDate: addDays(today(), 1), frequency: "Daily", totalDays: 1, amount: 350, deliveryFees: 50, discount: 0, paymentMethod: "InstaPay", paymentStatus: "Pending", referenceId: "IP-PENDING-22", proofName: "proof-dalia.jpg", status: "Pending Accounting", salesRepId: "emp-sales", createdAt: today(), adHocMealId: "meal-6" },
  ];
  const subscriptions: Subscription[] = [
    { id: "sub-1", subscriptionNumber: "SUB-26001", orderId: "order-1", clientId: "client-1", packageId: "pkg-a", size: "Regular", startDate: addDays(today(), -10), frequency: "Daily", totalDays: 24, consumedDays: 9, status: "Active", firstDeliveryCompleted: true, createdAt: addDays(today(), -12) },
    { id: "sub-2", subscriptionNumber: "SUB-26002", orderId: "order-2", clientId: "client-2", packageId: "pkg-b", size: "Regular", startDate: addDays(today(), -6), frequency: "Daily", totalDays: 24, consumedDays: 5, status: "Active", firstDeliveryCompleted: true, createdAt: addDays(today(), -7) },
  ];
  const fulfillment: FulfillmentDay[] = [
    { id: "ful-1", orderId: "order-1", subscriptionId: "sub-1", clientId: "client-1", date: addDays(today(), 1), dayNumber: 10, mealId: "meal-1", slot: "Lunch", size: "Regular", zone: 1, status: "Sent", source: "Monthly Menu" },
    { id: "ful-2", orderId: "order-2", subscriptionId: "sub-2", clientId: "client-2", date: addDays(today(), 1), dayNumber: 6, mealId: "meal-4", slot: "Breakfast", size: "Regular", zone: 2, status: "Ready", source: "Monthly Menu" },
    { id: "ful-3", orderId: "order-2", subscriptionId: "sub-2", clientId: "client-2", date: addDays(today(), 1), dayNumber: 6, mealId: "meal-2", slot: "Lunch", size: "Regular", zone: 2, status: "Ready", source: "Monthly Menu" },
    { id: "ful-4", orderId: "order-2", subscriptionId: "sub-2", clientId: "client-2", date: addDays(today(), 1), dayNumber: 6, mealId: "meal-3", slot: "Dinner", size: "Regular", zone: 2, status: "Ready", source: "Monthly Menu" },
    { id: "ful-5", orderId: "order-2", subscriptionId: "sub-2", clientId: "client-2", date: addDays(today(), 1), dayNumber: 6, mealId: "meal-5", slot: "Snack", size: "Regular", zone: 2, status: "Ready", source: "Monthly Menu" },
    { id: "ful-6", orderId: "order-1", subscriptionId: "sub-1", clientId: "client-1", date: addDays(today(), 2), dayNumber: 11, mealId: "meal-2", slot: "Lunch", size: "Regular", zone: 1, status: "Planned", source: "Monthly Menu" },
  ];
  return {
    employees: [
      { id: "emp-admin", name: "Hisham Essam", role: "admin", active: true },
      { id: "emp-sales", name: "Dalia", role: "sales", active: true },
      { id: "emp-cs", name: "Marwa", role: "cs", active: true },
      { id: "emp-kitchen", name: "Samir", role: "kitchen", active: true },
      { id: "emp-delivery", name: "Liza Hany", role: "delivery", active: true },
      { id: "emp-accounting", name: "Nour", role: "accounting", active: true },
    ], clients,
    complaints: [
      { id: "complaint-1", clientId: "client-1", category: "Taste", details: "الأرز محتاج تقليل ملح", status: "Resolved", createdAt: addDays(today(), -5) },
      { id: "complaint-2", clientId: "client-2", category: "Delivery", details: "تأخير 30 دقيقة", status: "Open", createdAt: addDays(today(), -1) },
    ], meals, packages, menu: monthlyMenu(meals), orders, subscriptions, fulfillment,
    riders: [
      { id: "rider-1", name: "كابتن أحمد", phone: "01011110001", active: true },
      { id: "rider-2", name: "كابتن محمود", phone: "01011110002", active: true },
      { id: "rider-3", name: "كابتن سارة", phone: "01011110003", active: true },
    ],
    deliveries: [{ id: "delivery-1", fulfillmentId: "ful-2", clientId: "client-2", orderId: "order-2", date: addDays(today(), 1), zone: 2, riderId: "rider-2", sequence: 1, status: "Pending", codExpected: 0, cashCollected: 0 }],
    payments: [
      { id: "pay-1", orderId: "order-1", clientId: "client-1", method: "InstaPay", amount: 4628, status: "Verified", referenceId: "IP-884201", proofName: "instapay-ahmed.jpg", verifiedAt: addDays(today(), -12), verifiedBy: "Nour", createdAt: addDays(today(), -12) },
      { id: "pay-2", orderId: "order-2", clientId: "client-2", method: "Website/App", amount: 13883, status: "Verified", referenceId: "WEB-99012", proofName: "web-order.png", verifiedAt: addDays(today(), -7), verifiedBy: "Nour", createdAt: addDays(today(), -7) },
      { id: "pay-3", orderId: "order-3", clientId: "client-3", method: "Cash", amount: 7380, status: "Pending", createdAt: today() },
      { id: "pay-4", orderId: "order-4", clientId: "client-4", method: "InstaPay", amount: 350, status: "Pending", referenceId: "IP-PENDING-22", proofName: "proof-dalia.jpg", createdAt: today() },
    ],
    cancellations: [],
    notifications: [
      { id: "note-1", role: "accounting", title: "دفعتان بانتظار المراجعة", body: "راجع مرجع الدفع والصورة ثم أكد أو ارفض.", read: false, createdAt: nowLabel() },
      { id: "note-2", role: "kitchen", title: "إنتاج بكرة جاهز", body: "تم إرسال أحمد علي للمطبخ، ويوجد Full Day لمنة خالد.", read: false, createdAt: nowLabel() },
      { id: "note-3", role: "sales", title: "متابعة التجديد", body: "راجع الاشتراكات المتبقي بها 3 أيام أو أقل.", read: false, createdAt: nowLabel() },
    ],
    salesTargets: [{ id: "target-1", employeeId: "emp-sales", month: today().slice(0, 7), target: 25000 }],
    reconciliations: [{ id: "rec-1", date: today(), expectedCash: 0, actualCash: 0, instapayVerified: 0, status: "Open" }],
  };
}

function mealFor(state: ERPState, date: string, slot: MenuEntry["slot"]) {
  return state.menu.find((item) => item.date === date && item.slot === slot)?.mealId
    ?? state.meals.find((item) => item.slot === slot && item.active)?.id
    ?? state.meals[0]?.id;
}

function generateSchedule(state: ERPState, order: Order, subscription: Subscription): FulfillmentDay[] {
  const client = state.clients.find((item) => item.id === order.clientId);
  const pkg = state.packages.find((item) => item.id === order.packageId);
  if (!client || !pkg) return [];
  const result: FulfillmentDay[] = [];
  let cursor = order.startDate;
  let dayNumber = 1;
  let safety = 0;
  while (dayNumber <= order.totalDays && safety < 730) {
    const date = new Date(`${cursor}T12:00:00`);
    const weekDay = date.getDay();
    const eligible = order.frequency === "Weekly" ? weekDay === (order.weeklyDay ?? 6) : weekDay !== 5;
    if (eligible) {
      for (const slot of pkg.mealSlots) {
        const mealId = mealFor(state, cursor, slot);
        if (mealId) result.push({ id: id("ful"), orderId: order.id, subscriptionId: subscription.id, clientId: order.clientId, date: cursor, dayNumber, mealId, slot, size: order.size, zone: client.zone, status: "Planned", source: "Monthly Menu" });
      }
      dayNumber += 1;
    }
    cursor = addDays(cursor, 1);
    safety += 1;
  }
  return result;
}

export function commissionRate(percent: number) {
  if (percent < 80) return 0; if (percent < 100) return 3; if (percent < 120) return 3.5; if (percent <= 150) return 4; return 5;
}

export function ERPProvider({ children }: { children: React.ReactNode }) {
  const [role, setRoleState] = React.useState<Role>("admin");
  const [state, setState] = React.useState<ERPState>(() => makeDemoState());
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState("");
  const demoMode = process.env.NEXT_PUBLIC_DEMO_MODE !== "false" || !process.env.NEXT_PUBLIC_SUPABASE_URL;

  const refreshLive = React.useCallback(async () => {
    if (demoMode) return;
    try {
      const supabase = createSupabaseClient();
      const { data, error: rpcError } = await supabase.rpc("erp_bootstrap");
      if (rpcError) throw rpcError;
      setState(data as ERPState);
      setError("");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "تعذر تحميل البيانات من Supabase");
    }
  }, [demoMode]);

  React.useEffect(() => {
    const savedRole = window.localStorage.getItem("eco-role") as Role | null;
    if (savedRole) setRoleState(savedRole);
    if (demoMode) {
      const saved = window.localStorage.getItem("eco-erp-v4");
      if (saved) try { setState(JSON.parse(saved) as ERPState); } catch { window.localStorage.removeItem("eco-erp-v4"); }
      setLoading(false);
    } else refreshLive().finally(() => setLoading(false));
  }, [demoMode, refreshLive]);

  React.useEffect(() => { if (demoMode && !loading) window.localStorage.setItem("eco-erp-v4", JSON.stringify(state)); }, [state, demoMode, loading]);

  function setRole(next: Role) { setRoleState(next); window.localStorage.setItem("eco-role", next); }
  function update(mutator: (current: ERPState) => ERPState) { setState((current) => mutator(current)); }
  function notify(current: ERPState, targetRole: Role, title: string, body: string): ERPState {
    return { ...current, notifications: [{ id: id("note"), role: targetRole, title, body, read: false, createdAt: nowLabel() }, ...current.notifications] };
  }
  async function rpc(command: string, payload: Record<string, unknown>, demoAction: () => Result): Promise<Result> {
    if (demoMode) return demoAction();
    try {
      const supabase = createSupabaseClient();
      const { data, error: rpcError } = await supabase.rpc(command, payload);
      if (rpcError) throw rpcError;
      await refreshLive();
      const record = data as { id?: string; message?: string } | null;
      return { ok: true, id: record?.id, message: record?.message ?? "تم الحفظ" };
    } catch (cause) { return { ok: false, message: cause instanceof Error ? cause.message : "تعذر تنفيذ العملية" }; }
  }

  function resetDemo() { const fresh = makeDemoState(); setState(fresh); window.localStorage.setItem("eco-erp-v4", JSON.stringify(fresh)); }
  async function purgeDemo() {
    if (demoMode) {
      update((s) => ({ ...s, clients: s.clients.filter((x) => !x.isDemo), complaints: [], orders: [], subscriptions: [], fulfillment: [], deliveries: [], payments: [], cancellations: [], notifications: [] }));
      return;
    }
    const supabase = createSupabaseClient();
    const { error: rpcError } = await supabase.rpc("erp_purge_demo_data");
    if (rpcError) setError(rpcError.message); else await refreshLive();
  }

  async function addClient(input: NewClientInput) {
    return rpc("erp_create_client", { p_payload: input }, () => { const newId = id("client"); update((s) => ({ ...s, clients: [{ ...input, id: newId, totalPaid: 0, createdAt: today() }, ...s.clients] })); return { ok: true, id: newId, message: "تم تسجيل العميل" }; });
  }
  async function addComplaint(clientId: string, category: string, details: string) {
    return rpc("erp_add_complaint", { p_client_id: clientId, p_category: category, p_details: details }, () => { const newId = id("complaint"); update((s) => ({ ...s, complaints: [{ id: newId, clientId, category, details, status: "Open", createdAt: today() }, ...s.complaints] })); return { ok: true, id: newId, message: "تم تسجيل الشكوى" }; });
  }
  async function resolveComplaint(complaintId: string) {
    return rpc("erp_resolve_complaint", { p_complaint_id: complaintId }, () => { update((s) => ({ ...s, complaints: s.complaints.map((x) => x.id === complaintId ? { ...x, status: "Resolved" } : x) })); return { ok: true, message: "تم إغلاق الشكوى" }; });
  }
  async function addMeal(input: Omit<Meal, "id">) {
    return rpc("erp_create_meal", { p_payload: input }, () => { const newId = id("meal"); update((s) => ({ ...s, meals: [{ ...input, id: newId }, ...s.meals] })); return { ok: true, id: newId, message: "تمت إضافة الوجبة" }; });
  }
  async function addPackage(input: Omit<Package, "id">) {
    return rpc("erp_create_package", { p_payload: input }, () => { const newId = id("pkg"); update((s) => ({ ...s, packages: [{ ...input, id: newId }, ...s.packages] })); return { ok: true, id: newId, message: "تمت إضافة الباكدج" }; });
  }
  async function upsertMenu(date: string, slot: MenuEntry["slot"], mealId: string, notes?: string) {
    return rpc("erp_upsert_menu", { p_date: date, p_slot: slot.toLowerCase(), p_meal_id: mealId, p_notes: notes ?? null }, () => { update((s) => ({ ...s, menu: [...s.menu.filter((x) => !(x.date === date && x.slot === slot)), { id: id("menu"), date, slot, mealId, notes }] })); return { ok: true, message: "تم حفظ منيو اليوم" }; });
  }
  async function createOrder(input: NewOrderInput) {
    if (["InstaPay", "Website/App", "Bank Transfer"].includes(input.paymentMethod) && (!input.referenceId || !input.proofName)) return { ok: false, message: "رقم المرجع وصورة إثبات الدفع مطلوبان" };
    return rpc("erp_create_order", { p_payload: input }, () => {
      const orderId = id("order"); const orderNumber = `ECO-${String(Date.now()).slice(-8)}`;
      const order: Order = { ...input, id: orderId, orderNumber, status: "Pending Accounting", paymentStatus: "Pending", createdAt: today() };
      const payment = { id: id("pay"), orderId, clientId: input.clientId, method: input.paymentMethod, amount: input.amount, status: "Pending" as const, referenceId: input.referenceId, proofName: input.proofName, createdAt: today() };
      update((s) => notify({ ...s, orders: [order, ...s.orders], payments: [payment, ...s.payments] }, "accounting", "طلب جديد ينتظر الاعتماد", `${orderNumber} بقيمة ${input.amount.toLocaleString("ar-EG")} ج`));
      return { ok: true, id: orderId, message: `تم إنشاء ${orderNumber} وإرساله للحسابات` };
    });
  }
  async function verifyPayment(paymentId: string) {
    return rpc("erp_verify_payment", { p_payment_id: paymentId }, () => {
      const payment = state.payments.find((x) => x.id === paymentId); if (!payment) return { ok: false, message: "عملية الدفع غير موجودة" };
      const order = state.orders.find((x) => x.id === payment.orderId); if (!order) return { ok: false, message: "الطلب غير موجود" };
      update((s) => {
        const approvedOrder: Order = { ...order, status: "Approved", paymentStatus: payment.method === "Cash" ? "COD" : "Verified" };
        let next: ERPState = { ...s,
          orders: s.orders.map((x) => x.id === order.id ? approvedOrder : x),
          payments: s.payments.map((x) => x.id === paymentId ? { ...x, status: payment.method === "Cash" ? "COD" : "Verified", verifiedAt: today(), verifiedBy: "Accounting" } : x),
        };
        if (order.kind === "Subscription" && order.packageId) {
          const sub: Subscription = { id: id("sub"), subscriptionNumber: `SUB-${String(Date.now()).slice(-7)}`, orderId: order.id, clientId: order.clientId, packageId: order.packageId, size: order.size, startDate: order.startDate, frequency: order.frequency, weeklyDay: order.weeklyDay, totalDays: order.totalDays, consumedDays: 0, status: "Active", firstDeliveryCompleted: false, createdAt: today() };
          next = { ...next, subscriptions: [sub, ...next.subscriptions], fulfillment: [...next.fulfillment, ...generateSchedule(next, approvedOrder, sub)] };
        } else if (order.adHocMealId) {
          const client = next.clients.find((x) => x.id === order.clientId); const meal = next.meals.find((x) => x.id === order.adHocMealId);
          if (client && meal) next = { ...next, fulfillment: [...next.fulfillment, { id: id("ful"), orderId: order.id, clientId: order.clientId, date: order.deliveryDate ?? order.startDate, dayNumber: 1, mealId: meal.id, slot: meal.slot, size: order.size, zone: client.zone, status: "Planned", source: "Ad Hoc" }] };
        }
        return notify(next, "kitchen", "طلب معتمد أصبح متاحًا", `${order.orderNumber} أصبح مؤهلًا للإرسال للمطبخ`);
      });
      return { ok: true, message: "تم اعتماد الدفع وفتح الطلب للتشغيل" };
    });
  }
  async function rejectPayment(paymentId: string) {
    return rpc("erp_reject_payment", { p_payment_id: paymentId }, () => { const payment = state.payments.find((x) => x.id === paymentId); update((s) => ({ ...s, payments: s.payments.map((x) => x.id === paymentId ? { ...x, status: "Rejected" } : x), orders: s.orders.map((x) => x.id === payment?.orderId ? { ...x, status: "Rejected", paymentStatus: "Rejected" } : x) })); return { ok: true, message: "تم رفض الدفع" }; });
  }
  async function pauseSubscription(subscriptionId: string, until?: string, indefinite?: boolean) {
    return rpc("erp_pause_subscription", { p_subscription_id: subscriptionId, p_until: until ?? null, p_indefinite: Boolean(indefinite) }, () => { update((s) => ({ ...s, subscriptions: s.subscriptions.map((x) => x.id === subscriptionId ? { ...x, status: "Paused", pauseFrom: today(), pauseUntil: until, indefinitePause: indefinite } : x) })); return { ok: true, message: "تم إيقاف الاشتراك" }; });
  }
  async function resumeSubscription(subscriptionId: string) {
    return rpc("erp_resume_subscription", { p_subscription_id: subscriptionId }, () => { update((s) => ({ ...s, subscriptions: s.subscriptions.map((x) => x.id === subscriptionId ? { ...x, status: "Active", pauseFrom: undefined, pauseUntil: undefined, indefinitePause: false } : x) })); return { ok: true, message: "تم استئناف الاشتراك" }; });
  }
  async function skipTomorrow(subscriptionId: string) {
    const date = addDays(today(), 1);
    return rpc("erp_skip_subscription_day", { p_subscription_id: subscriptionId, p_date: date }, () => { update((s) => ({ ...s, fulfillment: s.fulfillment.map((x) => x.subscriptionId === subscriptionId && x.date === date && x.status === "Planned" ? { ...x, skipped: true } : x) })); return { ok: true, message: "تم تخطي توصيل الغد" }; });
  }
  async function swapMeal(fulfillmentId: string, mealId: string) {
    return rpc("erp_swap_meal", { p_fulfillment_id: fulfillmentId, p_meal_id: mealId }, () => { update((s) => ({ ...s, fulfillment: s.fulfillment.map((x) => x.id === fulfillmentId ? { ...x, mealId, source: "Meal Swap" } : x) })); return { ok: true, message: "تم تبديل الوجبة لهذا العميل فقط" }; });
  }
  async function requestCancellation(subscriptionId: string, reason: string) {
    return rpc("erp_request_cancellation", { p_subscription_id: subscriptionId, p_reason: reason }, () => {
      const sub = state.subscriptions.find((x) => x.id === subscriptionId); const order = state.orders.find((x) => x.id === sub?.orderId);
      if (!sub || !order) return { ok: false, message: "الاشتراك غير موجود" };
      const dayValue = order.amount / Math.max(sub.totalDays, 1); const consumedValue = dayValue * sub.consumedDays; const remainingValue = dayValue * Math.max(sub.totalDays - sub.consumedDays, 0); const consumedPenalty = consumedValue * 0.2;
      const deliveryDays = new Set(state.deliveries.filter((x) => x.orderId === order.id && x.status === "Delivered").map((x) => x.date)).size; const deliveryPenalty = deliveryDays * 30; const refundAmount = Math.max(0, remainingValue - consumedPenalty - deliveryPenalty);
      const cancellation: Cancellation = { id: id("cancel"), subscriptionId, clientId: sub.clientId, orderId: order.id, remainingValue, consumedValue, consumedPenalty, deliveryPenalty, refundAmount, reason, status: "Requested", createdAt: today() };
      update((s) => notify({ ...s, cancellations: [cancellation, ...s.cancellations] }, "accounting", "طلب إلغاء جديد", `Refund ${refundAmount.toFixed(2)} ج يحتاج مراجعة`));
      return { ok: true, id: cancellation.id, message: "تم إرسال طلب الإلغاء للحسابات" };
    });
  }
  async function reviewCancellation(cancellationId: string) {
    return rpc("erp_review_cancellation", { p_cancellation_id: cancellationId }, () => { update((s) => ({ ...s, cancellations: s.cancellations.map((x) => x.id === cancellationId ? { ...x, status: "Reviewed" } : x) })); return { ok: true, message: "تمت مراجعة الحساب" }; });
  }
  async function transferCancellation(cancellationId: string, receiptName: string) {
    return rpc("erp_transfer_cancellation", { p_cancellation_id: cancellationId, p_receipt_name: receiptName }, () => { const cancellation = state.cancellations.find((x) => x.id === cancellationId); update((s) => ({ ...s, cancellations: s.cancellations.map((x) => x.id === cancellationId ? { ...x, status: "Transferred", receiptName } : x), subscriptions: s.subscriptions.map((x) => x.id === cancellation?.subscriptionId ? { ...x, status: "Canceled" } : x), orders: s.orders.map((x) => x.id === cancellation?.orderId ? { ...x, status: "Canceled" } : x) })); return { ok: true, message: "تم التحويل وإغلاق الاشتراك" }; });
  }
  async function sendToKitchen(fulfillmentIds: string[]) {
    return rpc("erp_send_to_kitchen", { p_fulfillment_ids: fulfillmentIds }, () => { update((s) => ({ ...s, fulfillment: s.fulfillment.map((x) => fulfillmentIds.includes(x.id) && !x.skipped ? { ...x, status: "Sent" } : x) })); return { ok: true, message: `تم إرسال ${fulfillmentIds.length} بند للمطبخ` }; });
  }
  async function addEmergencyFulfillment(date: string, clientId: string, mealId: string) {
    return rpc("erp_add_emergency_fulfillment", { p_date: date, p_client_id: clientId, p_meal_id: mealId }, () => {
      const client = state.clients.find((x) => x.id === clientId); const meal = state.meals.find((x) => x.id === mealId);
      if (!client || !meal) return { ok: false, message: "العميل أو الوجبة غير موجودة" };
      const row: FulfillmentDay = { id: id("emergency"), orderId: "manual", clientId, date, dayNumber: 1, mealId, slot: meal.slot, size: "Regular", zone: client.zone, status: "Sent", source: "Ad Hoc", manualAfterCutoff: true };
      update((s) => notify({ ...s, fulfillment: [row, ...s.fulfillment] }, "kitchen", "إضافة طارئة بعد الـCut-off", `${client.name} · ${meal.name} · ${date}`));
      return { ok: true, id: row.id, message: "تمت الإضافة الطارئة وتنبيه المطبخ" };
    });
  }
  async function setKitchenStatus(fulfillmentIds: string[], status: KitchenStatus) {
    return rpc("erp_set_kitchen_status", { p_fulfillment_ids: fulfillmentIds, p_status: status.toLowerCase().replaceAll(" ", "_") }, () => {
      update((s) => {
        let next = { ...s, fulfillment: s.fulfillment.map((x) => fulfillmentIds.includes(x.id) ? { ...x, status } : x) };
        if (status === "Ready") {
          const readyRows = next.fulfillment.filter((x) => fulfillmentIds.includes(x.id));
          for (const row of readyRows) {
            const exists = next.deliveries.some((x) => x.orderId === row.orderId && x.clientId === row.clientId && x.date === row.date);
            if (!exists) {
              const order = next.orders.find((x) => x.id === row.orderId); const payment = next.payments.find((x) => x.orderId === row.orderId);
              const cod = payment?.status === "COD" ? order?.amount ?? 0 : 0;
              next = { ...next, deliveries: [...next.deliveries, { id: id("delivery"), fulfillmentId: row.id, clientId: row.clientId, orderId: row.orderId, date: row.date, zone: row.zone, sequence: next.deliveries.filter((x) => x.date === row.date && x.zone === row.zone).length + 1, status: "Pending", codExpected: cod, cashCollected: 0 }] };
            }
          }
        }
        return next;
      });
      return { ok: true, message: "تم تحديث حالة المطبخ" };
    });
  }
  async function assignRider(date: string, zone: Zone, riderId: string) {
    return rpc("erp_assign_rider", { p_date: date, p_zone: zone, p_rider_id: riderId }, () => { update((s) => ({ ...s, deliveries: s.deliveries.map((x) => x.date === date && x.zone === zone ? { ...x, riderId } : x) })); return { ok: true, message: `تم تعيين الكابتن للمنطقة ${zone}` }; });
  }
  async function setDeliveryStatus(deliveryId: string, status: DeliveryStop["status"]) {
    return rpc("erp_set_delivery_status", { p_delivery_id: deliveryId, p_status: status.toLowerCase().replaceAll(" ", "_") }, () => {
      const delivery = state.deliveries.find((x) => x.id === deliveryId); if (!delivery) return { ok: false, message: "التوصيل غير موجود" };
      const order = state.orders.find((x) => x.id === delivery.orderId); const payment = state.payments.find((x) => x.orderId === delivery.orderId); const sub = state.subscriptions.find((x) => x.orderId === delivery.orderId);
      if (status === "Delivered" && payment?.status === "COD" && sub?.firstDeliveryCompleted) return { ok: false, message: "Gatekeeper: العميل استلم أول مرة والدفع لم يُحصّل بعد" };
      update((s) => {
        let next: ERPState = { ...s, deliveries: s.deliveries.map((x) => x.id === deliveryId ? { ...x, status, deliveredAt: status === "Delivered" ? nowLabel() : x.deliveredAt } : x) };
        if (status === "Delivered") {
          next = { ...next, subscriptions: next.subscriptions.map((x) => x.orderId === delivery.orderId ? { ...x, consumedDays: Math.min(x.totalDays, x.consumedDays + 1), firstDeliveryCompleted: true, status: x.consumedDays + 1 >= x.totalDays ? "Finished" : x.status } : x), fulfillment: next.fulfillment.map((x) => x.orderId === delivery.orderId && x.date === delivery.date ? { ...x, status: "Ready" } : x) };
          const updatedSub = next.subscriptions.find((x) => x.orderId === delivery.orderId); const remaining = updatedSub ? updatedSub.totalDays - updatedSub.consumedDays : 99;
          if (remaining <= 3 && remaining > 0) next = notify(next, "sales", "اشتراك قرب يخلص", `باقي ${remaining} يوم فقط. تواصل للتجديد.`);
          if (payment?.status === "COD" && order) next = notify(next, "accounting", "تم أول تسليم بدون تحصيل مؤكد", `${order.orderNumber} سيتوقف ماليًا قبل اليوم التالي`);
        }
        return next;
      });
      return { ok: true, message: "تم تحديث حالة التوصيل" };
    });
  }
  async function collectCash(deliveryId: string, amount: number, method: PaymentMethod) {
    return rpc("erp_collect_cash", { p_delivery_id: deliveryId, p_amount: amount, p_method: method.toLowerCase().replaceAll("/", "_").replaceAll(" ", "_") }, () => {
      const delivery = state.deliveries.find((x) => x.id === deliveryId); update((s) => notify({ ...s, deliveries: s.deliveries.map((x) => x.id === deliveryId ? { ...x, cashCollected: amount, collectionMethod: method } : x), payments: s.payments.map((x) => x.orderId === delivery?.orderId ? { ...x, status: "Verified", verifiedAt: today(), verifiedBy: "Rider collection" } : x), orders: s.orders.map((x) => x.id === delivery?.orderId ? { ...x, paymentStatus: "Verified" } : x) }, "accounting", "تحصيل نقدي جديد", `سجل الكابتن تحصيل ${amount.toLocaleString("ar-EG")} ج`)); return { ok: true, message: "تم تسجيل التحصيل وإرساله للحسابات" };
    });
  }
  async function closeReconciliation(reconciliationId: string, actualCash: number) {
    return rpc("erp_close_reconciliation", { p_reconciliation_id: reconciliationId, p_actual_cash: actualCash }, () => { update((s) => ({ ...s, reconciliations: s.reconciliations.map((x) => x.id === reconciliationId ? { ...x, actualCash, status: "Closed" } : x) })); return { ok: true, message: "تم إغلاق اليوم" }; });
  }
  function markNotificationRead(notificationId: string) { update((s) => ({ ...s, notifications: s.notifications.map((x) => x.id === notificationId ? { ...x, read: true } : x) })); }
  function markAllNotificationsRead() { update((s) => ({ ...s, notifications: s.notifications.map((x) => role === "admin" || x.role === role ? { ...x, read: true } : x) })); }

  return <ERPContext.Provider value={{ ...state, role, setRole, demoMode, loading, error, resetDemo, purgeDemo, addClient, addComplaint, resolveComplaint, addMeal, addPackage, upsertMenu, createOrder, verifyPayment, rejectPayment, pauseSubscription, resumeSubscription, skipTomorrow, swapMeal, requestCancellation, reviewCancellation, transferCancellation, sendToKitchen, addEmergencyFulfillment, setKitchenStatus, assignRider, setDeliveryStatus, collectCash, closeReconciliation, markNotificationRead, markAllNotificationsRead }}>{children}</ERPContext.Provider>;
}

export function useERP() { const value = React.useContext(ERPContext); if (!value) throw new Error("useERP must be used inside ERPProvider"); return value; }
