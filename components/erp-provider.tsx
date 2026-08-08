"use client";

import * as React from "react";
import type {
  AppNotification,
  CancellationRequest,
  Client,
  DeliveryStop,
  FulfillmentDay,
  KitchenStatus,
  MealType,
  Role,
  SalesRep,
  Subscription,
} from "@/lib/erp-types";

type ERPContextValue = {
  role: Role;
  setRole: (role: Role) => void;
  clients: Client[];
  subscriptions: Subscription[];
  fulfillmentDays: FulfillmentDay[];
  deliveries: DeliveryStop[];
  cancellations: CancellationRequest[];
  notifications: AppNotification[];
  salesReps: SalesRep[];
  addIssue: (clientId: string, text: string, imageUrl?: string) => void;
  togglePause: (subscriptionId: string) => void;
  swapMeal: (fulfillmentDayId: string, meal: string, mealType: MealType) => void;
  setKitchenStatus: (fulfillmentDayId: string, status: KitchenStatus) => void;
  addVipAfterCutoff: () => void;
  assignRider: (deliveryId: string, rider: string) => void;
  logCashCollection: (deliveryId: string) => void;
  markDelivered: (deliveryId: string) => void;
  verifyPayment: (subscriptionId: string) => void;
  requestCancellation: (subscriptionId: string) => CancellationRequest | undefined;
  reviewCancellation: (requestId: string) => void;
  confirmTransfer: (requestId: string, receiptUrl: string) => void;
  markNotificationRead: (notificationId: string) => void;
  markAllNotificationsRead: () => void;
};

const ERPContext = React.createContext<ERPContextValue | null>(null);

function isoDate(offsetDays = 0) {
  const date = new Date();
  date.setDate(date.getDate() + offsetDays);
  return date.toISOString().slice(0, 10);
}

const initialClients: Client[] = [
  { id: "c1", name: "أحمد علي", phone: "01090000001", zone: 1, locationUrl: "https://maps.google.com/?q=30.05,31.24", dietaryNotes: "بدون بصل", issues: [{ id: "i1", text: "طلب تقليل الملح في الوجبات القادمة", createdAt: "2026-08-07 14:20" }] },
  { id: "c2", name: "منة خالد", phone: "01090000002", zone: 2, locationUrl: "https://maps.google.com/?q=30.01,31.42", dietaryNotes: "LC - بدون صوص", issues: [] },
  { id: "c3", name: "كريم سمير", phone: "01090000003", zone: 1, locationUrl: "https://maps.google.com/?q=30.09,31.33", dietaryNotes: "لا يوجد", issues: [] },
  { id: "c4", name: "داليا محمد", phone: "01090000004", zone: 3, locationUrl: "https://maps.google.com/?q=29.96,31.26", dietaryNotes: "حساسية من الفلفل الحار", issues: [{ id: "i2", text: "العميلة مسافرة وطلبت إيقاف مؤقت", createdAt: "2026-08-06 10:15" }] },
  { id: "c5", name: "عمر حسن", phone: "01090000005", zone: 2, locationUrl: "https://maps.google.com/?q=30.04,31.20", dietaryNotes: "High Protein", issues: [] },
  { id: "c6", name: "نور أحمد", phone: "01090000006", zone: 1, locationUrl: "https://maps.google.com/?q=30.06,31.22", dietaryNotes: "لا يوجد", issues: [] },
  { id: "c7", name: "سارة عادل", phone: "01090000007", zone: 4, locationUrl: "https://maps.google.com/?q=30.10,31.49", dietaryNotes: "VIP - بدون ألبان", issues: [] },
  { id: "c8", name: "محمد شريف", phone: "01090000008", zone: 4, locationUrl: "https://maps.google.com/?q=29.97,30.94", dietaryNotes: "Weekly delivery", issues: [] },
];

const initialSubscriptions: Subscription[] = [
  { id: "s1", clientId: "c1", salesRepId: "sales1", program: "Weight Loss Lunch", totalDays: 24, consumedDays: 10, totalPrice: 4800, status: "Active", deliveryType: "Daily", paymentType: "PrePaid", amountPaid: 4800, paymentVerified: true, firstDeliveryCompleted: true, deliveryDaysLogged: 10 },
  { id: "s2", clientId: "c2", salesRepId: "sales1", program: "Full Day LC", totalDays: 18, consumedDays: 0, totalPrice: 5400, status: "Active", deliveryType: "Daily", paymentType: "PayOnFirstDelivery", amountPaid: 0, paymentVerified: false, firstDeliveryCompleted: false, deliveryDaysLogged: 0 },
  { id: "s3", clientId: "c3", salesRepId: "sales1", program: "Weight Loss", totalDays: 12, consumedDays: 10, totalPrice: 3600, status: "Active", deliveryType: "Daily", paymentType: "PrePaid", amountPaid: 3600, paymentVerified: true, firstDeliveryCompleted: true, deliveryDaysLogged: 10 },
  { id: "s4", clientId: "c4", salesRepId: "sales2", program: "Lunch Plan", totalDays: 20, consumedDays: 8, totalPrice: 4000, status: "Paused", deliveryType: "Daily", paymentType: "PrePaid", amountPaid: 4000, paymentVerified: true, firstDeliveryCompleted: true, deliveryDaysLogged: 8 },
  { id: "s5", clientId: "c5", salesRepId: "sales2", program: "Muscle Gain", totalDays: 18, consumedDays: 15, totalPrice: 5400, status: "Active", deliveryType: "Daily", paymentType: "PrePaid", amountPaid: 5400, paymentVerified: true, firstDeliveryCompleted: true, deliveryDaysLogged: 15 },
  { id: "s6", clientId: "c6", salesRepId: "sales2", program: "Starter Plan", totalDays: 10, consumedDays: 10, totalPrice: 2500, status: "Finished", deliveryType: "Daily", paymentType: "PrePaid", amountPaid: 2500, paymentVerified: true, firstDeliveryCompleted: true, deliveryDaysLogged: 10 },
  { id: "s7", clientId: "c1", salesRepId: "sales2", program: "Dinner Add-on", totalDays: 12, consumedDays: 7, totalPrice: 2100, status: "Active", deliveryType: "Weekly", weeklyDay: "السبت", paymentType: "PrePaid", amountPaid: 2100, paymentVerified: true, firstDeliveryCompleted: true, deliveryDaysLogged: 2 },
  { id: "s8", clientId: "c7", salesRepId: "sales1", program: "VIP High Protein", totalDays: 24, consumedDays: 1, totalPrice: 7200, status: "Active", deliveryType: "Daily", paymentType: "PayOnFirstDelivery", amountPaid: 0, paymentVerified: false, firstDeliveryCompleted: true, deliveryDaysLogged: 1 },
  { id: "s9", clientId: "c8", salesRepId: "sales2", program: "Weekly Pack", totalDays: 24, consumedDays: 4, totalPrice: 6000, status: "Active", deliveryType: "Weekly", weeklyDay: "السبت", paymentType: "PrePaid", amountPaid: 6000, paymentVerified: true, firstDeliveryCompleted: true, deliveryDaysLogged: 1 },
];

const initialFulfillment: FulfillmentDay[] = [
  { id: "f1", subscriptionId: "s1", dayNumber: 11, date: isoDate(1), meal: "Grilled Chicken", mealType: "Standard", zone: 1, kitchenStatus: "Pending" },
  { id: "f2", subscriptionId: "s2", dayNumber: 1, date: isoDate(1), meal: "LC Chicken", mealType: "LC", zone: 2, kitchenStatus: "In Prep" },
  { id: "f3", subscriptionId: "s3", dayNumber: 11, date: isoDate(1), meal: "Smoky Grilled Chicken", mealType: "Standard", zone: 1, kitchenStatus: "Approved/Done" },
  { id: "f4", subscriptionId: "s5", dayNumber: 16, date: isoDate(1), meal: "Beef Burger", mealType: "High Protein", zone: 2, kitchenStatus: "Pending" },
  { id: "f5", subscriptionId: "s7", dayNumber: 8, date: isoDate(1), meal: "Chicken Burger Wrap", mealType: "Standard", zone: 1, kitchenStatus: "Pending" },
  { id: "f6", subscriptionId: "s8", dayNumber: 2, date: isoDate(1), meal: "HP Chicken Rice", mealType: "High Protein", zone: 4, kitchenStatus: "Pending" },
  { id: "f7", subscriptionId: "s9", dayNumber: 5, date: isoDate(1), meal: "Weekly Meal Pack", mealType: "Standard", zone: 4, kitchenStatus: "Approved/Done" },
  { id: "f8", subscriptionId: "s1", dayNumber: 12, date: isoDate(2), meal: "Chicken Burger", mealType: "Standard", zone: 1, kitchenStatus: "Pending" },
];

const initialDeliveries: DeliveryStop[] = [
  { id: "d1", fulfillmentDayId: "f1", subscriptionId: "s1", clientId: "c1", zone: 1, rider: "كابتن أحمد", status: "Pending", cashExpected: 0, collectionLogged: false },
  { id: "d2", fulfillmentDayId: "f2", subscriptionId: "s2", clientId: "c2", zone: 2, rider: "كابتن سارة", status: "Pending", cashExpected: 5400, collectionLogged: false },
  { id: "d3", fulfillmentDayId: "f3", subscriptionId: "s3", clientId: "c3", zone: 1, rider: "كابتن أحمد", status: "Pending", cashExpected: 0, collectionLogged: false },
  { id: "d4", fulfillmentDayId: "f4", subscriptionId: "s5", clientId: "c5", zone: 2, rider: "كابتن سارة", status: "Pending", cashExpected: 0, collectionLogged: false },
  { id: "d5", fulfillmentDayId: "f6", subscriptionId: "s8", clientId: "c7", zone: 4, rider: "كابتن محمود", status: "Pending", cashExpected: 0, collectionLogged: false },
  { id: "d6", fulfillmentDayId: "f7", subscriptionId: "s9", clientId: "c8", zone: 4, rider: "كابتن محمود", status: "Pending", cashExpected: 0, collectionLogged: false },
];

const initialNotifications: AppNotification[] = [
  { id: "n1", role: "sales", title: "اشتراك قرب يخلص", body: "كريم سمير باقي له يومين فقط. تواصل معه للتجديد.", type: "sales", read: false, createdAt: "منذ 10 دقائق" },
  { id: "n2", role: "accounting", title: "عميل محظور ماليًا", body: "سارة عادل استلمت أول توصيل ولم يتم تأكيد الدفع.", type: "accounting", read: false, createdAt: "منذ 25 دقيقة" },
  { id: "n3", role: "kitchen", title: "قائمة بكرة مقفولة", body: "تم تنفيذ Cut-off تلقائي وتجهيز قائمة إنتاج الغد.", type: "kitchen", read: false, createdAt: "اليوم 17:00" },
];

const initialSalesReps: SalesRep[] = [
  { id: "sales1", name: "علي", target: 15000 },
  { id: "sales2", name: "منى", target: 12000 },
];

const initialCancellations: CancellationRequest[] = [
  { id: "cancel-demo-1", subscriptionId: "s4", clientId: "c4", remainingValue: 2400, consumedValue: 1600, consumedPenalty: 320, deliveryPenalty: 240, refundAmount: 1840, status: "Requested", createdAt: "2026-08-08 11:30" },
];

function makeId(prefix: string) {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
}

export function isFinanciallyBlocked(subscription: Subscription) {
  return subscription.paymentType === "PayOnFirstDelivery" && subscription.firstDeliveryCompleted && !subscription.paymentVerified;
}

export function calculateCancellation(subscription: Subscription) {
  const pricePerDay = subscription.totalPrice / subscription.totalDays;
  const consumedValue = pricePerDay * subscription.consumedDays;
  const remainingValue = pricePerDay * Math.max(subscription.totalDays - subscription.consumedDays, 0);
  const consumedPenalty = consumedValue * 0.2;
  const deliveryPenalty = subscription.deliveryDaysLogged * 30;
  const refundAmount = Math.max(0, remainingValue - consumedPenalty - deliveryPenalty);
  return { consumedValue, remainingValue, consumedPenalty, deliveryPenalty, refundAmount };
}

export function commissionRate(achievementPercent: number) {
  if (achievementPercent < 80) return 0;
  if (achievementPercent < 100) return 3;
  if (achievementPercent < 120) return 3.5;
  if (achievementPercent <= 150) return 4;
  return 5;
}

export function ERPProvider({ children }: { children: React.ReactNode }) {
  const [role, setRoleState] = React.useState<Role>("admin");
  const [clients, setClients] = React.useState<Client[]>(initialClients);
  const [subscriptions, setSubscriptions] = React.useState<Subscription[]>(initialSubscriptions);
  const [fulfillmentDays, setFulfillmentDays] = React.useState<FulfillmentDay[]>(initialFulfillment);
  const [deliveries, setDeliveries] = React.useState<DeliveryStop[]>(initialDeliveries);
  const [cancellations, setCancellations] = React.useState<CancellationRequest[]>(initialCancellations);
  const [notifications, setNotifications] = React.useState<AppNotification[]>(initialNotifications);

  React.useEffect(() => {
    const saved = window.localStorage.getItem("eco-mock-role") as Role | null;
    if (saved && ["admin", "sales", "cs", "kitchen", "delivery", "accounting"].includes(saved)) setRoleState(saved);
  }, []);

  function setRole(nextRole: Role) {
    setRoleState(nextRole);
    window.localStorage.setItem("eco-mock-role", nextRole);
  }

  function addNotification(notification: Omit<AppNotification, "id" | "read" | "createdAt">) {
    setNotifications((current) => [{ ...notification, id: makeId("n"), read: false, createdAt: "الآن" }, ...current]);
  }

  function addIssue(clientId: string, text: string, imageUrl?: string) {
    if (!text.trim()) return;
    setClients((current) => current.map((client) => client.id === clientId ? { ...client, issues: [{ id: makeId("issue"), text: text.trim(), imageUrl: imageUrl?.trim() || undefined, createdAt: new Date().toLocaleString("ar-EG") }, ...client.issues] } : client));
  }

  function togglePause(subscriptionId: string) {
    setSubscriptions((current) => current.map((sub) => sub.id === subscriptionId ? { ...sub, status: sub.status === "Paused" ? "Active" : "Paused" } : sub));
  }

  function swapMeal(fulfillmentDayId: string, meal: string, mealType: MealType) {
    setFulfillmentDays((current) => current.map((day) => day.id === fulfillmentDayId ? { ...day, meal, mealType } : day));
  }

  function setKitchenStatus(fulfillmentDayId: string, status: KitchenStatus) {
    setFulfillmentDays((current) => current.map((day) => day.id === fulfillmentDayId ? { ...day, kitchenStatus: status } : day));
  }

  function addVipAfterCutoff() {
    const id = makeId("vip-day");
    setFulfillmentDays((current) => [...current, { id, subscriptionId: "s1", dayNumber: 99, date: isoDate(1), meal: "VIP Grilled Chicken", mealType: "Standard", zone: 1, kitchenStatus: "Pending", manualOverride: true }]);
    setDeliveries((current) => [...current, { id: makeId("vip-delivery"), fulfillmentDayId: id, subscriptionId: "s1", clientId: "c1", zone: 1, rider: "كابتن أحمد", status: "Pending", cashExpected: 0, collectionLogged: false }]);
    addNotification({ role: "kitchen", title: "إضافة طارئة بعد Cut-off", body: "Admin أضاف وجبة VIP إلى قائمة بكرة. راجع الكمية الجديدة.", type: "kitchen" });
  }

  function assignRider(deliveryId: string, rider: string) {
    setDeliveries((current) => current.map((delivery) => delivery.id === deliveryId ? { ...delivery, rider } : delivery));
  }

  function logCashCollection(deliveryId: string) {
    const delivery = deliveries.find((item) => item.id === deliveryId);
    if (!delivery || delivery.collectionLogged || delivery.cashExpected <= 0) return;
    const client = clients.find((item) => item.id === delivery.clientId);
    setDeliveries((current) => current.map((item) => item.id === deliveryId ? { ...item, collectionLogged: true } : item));
    addNotification({ role: "accounting", title: "تحصيل نقدي جديد", body: `${client?.name ?? "عميل"}: الكابتن سجل تحصيل ${delivery.cashExpected.toLocaleString("ar-EG")} ج. مطلوب مراجعة الحسابات.`, type: "accounting" });
  }

  function markDelivered(deliveryId: string) {
    const delivery = deliveries.find((item) => item.id === deliveryId);
    if (!delivery || delivery.status === "Delivered") return;
    const subscription = subscriptions.find((item) => item.id === delivery.subscriptionId);
    if (!subscription || isFinanciallyBlocked(subscription)) return;

    const nextConsumed = Math.min(subscription.consumedDays + 1, subscription.totalDays);
    setDeliveries((current) => current.map((item) => item.id === deliveryId ? { ...item, status: "Delivered" } : item));
    setSubscriptions((current) => current.map((item) => item.id === subscription.id ? { ...item, consumedDays: nextConsumed, deliveryDaysLogged: item.deliveryDaysLogged + 1, firstDeliveryCompleted: true, status: nextConsumed >= item.totalDays ? "Finished" : item.status } : item));
    setFulfillmentDays((current) => current.filter((day) => day.id !== delivery.fulfillmentDayId));

    const remaining = subscription.totalDays - nextConsumed;
    if (remaining > 0 && remaining <= 3) {
      const client = clients.find((item) => item.id === subscription.clientId);
      addNotification({ role: "sales", title: "اشتراك قرب يخلص", body: `${client?.name ?? "عميل"} باقي له ${remaining} يوم فقط.`, type: "sales" });
    }
    if (subscription.paymentType === "PayOnFirstDelivery" && !subscription.paymentVerified) {
      const client = clients.find((item) => item.id === subscription.clientId);
      addNotification({ role: "accounting", title: "مطلوب تأكيد PayOnFirstDelivery", body: `${client?.name ?? "عميل"} استلم أول توصيل. أي طلب مستقبلي سيظل محظوراً حتى تأكيد الدفع.`, type: "accounting" });
    }
  }

  function verifyPayment(subscriptionId: string) {
    setSubscriptions((current) => current.map((sub) => sub.id === subscriptionId ? { ...sub, paymentVerified: true, amountPaid: sub.totalPrice } : sub));
  }

  function requestCancellation(subscriptionId: string) {
    const subscription = subscriptions.find((item) => item.id === subscriptionId);
    if (!subscription || cancellations.some((item) => item.subscriptionId === subscriptionId && item.status !== "Transferred")) return undefined;
    const values = calculateCancellation(subscription);
    const request: CancellationRequest = { id: makeId("cancel"), subscriptionId, clientId: subscription.clientId, ...values, status: "Requested", createdAt: new Date().toLocaleString("ar-EG") };
    setCancellations((current) => [request, ...current]);
    addNotification({ role: "accounting", title: "طلب إلغاء جديد", body: `طلب Refund بقيمة ${request.refundAmount.toLocaleString("ar-EG", { maximumFractionDigits: 2 })} ج بانتظار المراجعة.`, type: "accounting" });
    return request;
  }

  function reviewCancellation(requestId: string) {
    setCancellations((current) => current.map((item) => item.id === requestId ? { ...item, status: "Reviewed" } : item));
  }

  function confirmTransfer(requestId: string, receiptUrl: string) {
    const request = cancellations.find((item) => item.id === requestId);
    if (!request || !receiptUrl.trim()) return;
    setCancellations((current) => current.map((item) => item.id === requestId ? { ...item, status: "Transferred", receiptUrl: receiptUrl.trim() } : item));
    setSubscriptions((current) => current.map((sub) => sub.id === request.subscriptionId ? { ...sub, status: "Canceled" } : sub));
  }

  function markNotificationRead(notificationId: string) {
    setNotifications((current) => current.map((item) => item.id === notificationId ? { ...item, read: true } : item));
  }

  function markAllNotificationsRead() {
    setNotifications((current) => current.map((item) => role === "admin" || item.role === role ? { ...item, read: true } : item));
  }

  return (
    <ERPContext.Provider value={{ role, setRole, clients, subscriptions, fulfillmentDays, deliveries, cancellations, notifications, salesReps: initialSalesReps, addIssue, togglePause, swapMeal, setKitchenStatus, addVipAfterCutoff, assignRider, logCashCollection, markDelivered, verifyPayment, requestCancellation, reviewCancellation, confirmTransfer, markNotificationRead, markAllNotificationsRead }}>
      {children}
    </ERPContext.Provider>
  );
}

export function useERP() {
  const context = React.useContext(ERPContext);
  if (!context) throw new Error("useERP must be used inside ERPProvider");
  return context;
}
