import { hasSupabaseConfig } from "@/lib/config";
import { createClient } from "@/lib/supabase/server";

export type DashboardStats = {
  clients: number;
  activeSubscriptions: number;
  kitchenTomorrow: number;
  endingSoon: number;
};

export type KitchenQueueRow = {
  id: string;
  production_date: string;
  client_name_snapshot: string;
  program_name_snapshot: string;
  meal_name_snapshot: string;
  meal_type: string;
  quantity: number;
  area_snapshot: string | null;
  delivery_note_snapshot: string | null;
  status: "waiting" | "preparing" | "done";
  locked: boolean;
};

export function cairoDate(offsetDays = 0) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Africa/Cairo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(new Date());

  const year = Number(parts.find((part) => part.type === "year")?.value);
  const month = Number(parts.find((part) => part.type === "month")?.value);
  const day = Number(parts.find((part) => part.type === "day")?.value);
  const shifted = new Date(Date.UTC(year, month - 1, day + offsetDays));

  return shifted.toISOString().slice(0, 10);
}

const demoQueue: KitchenQueueRow[] = [
  {
    id: "demo-1",
    production_date: cairoDate(1),
    client_name_snapshot: "أحمد علي",
    program_name_snapshot: "Weight Loss Lunch",
    meal_name_snapshot: "Grilled Chicken",
    meal_type: "standard",
    quantity: 1,
    area_snapshot: "مدينة نصر",
    delivery_note_snapshot: "قبل 3 العصر",
    status: "waiting",
    locked: true,
  },
  {
    id: "demo-2",
    production_date: cairoDate(1),
    client_name_snapshot: "منة خالد",
    program_name_snapshot: "Full Day LC",
    meal_name_snapshot: "LC Chicken",
    meal_type: "lc",
    quantity: 1,
    area_snapshot: "التجمع الخامس",
    delivery_note_snapshot: "اتصال قبل الوصول",
    status: "waiting",
    locked: true,
  },
];

export async function getDashboardStats(): Promise<DashboardStats> {
  if (!hasSupabaseConfig()) {
    return {
      clients: 128,
      activeSubscriptions: 76,
      kitchenTomorrow: demoQueue.length,
      endingSoon: 9,
    };
  }

  const supabase = await createClient();
  const tomorrow = cairoDate(1);

  const [clients, activeSubscriptions, kitchenTomorrow, endingSoon] =
    await Promise.all([
      supabase.from("clients").select("id", { count: "exact", head: true }),
      supabase
        .from("subscriptions")
        .select("id", { count: "exact", head: true })
        .eq("status", "active"),
      supabase
        .from("production_queue")
        .select("id", { count: "exact", head: true })
        .eq("production_date", tomorrow),
      supabase
        .from("subscription_balances")
        .select("subscription_id", { count: "exact", head: true })
        .gt("remaining_days", 0)
        .lte("remaining_days", 3),
    ]);

  return {
    clients: clients.count ?? 0,
    activeSubscriptions: activeSubscriptions.count ?? 0,
    kitchenTomorrow: kitchenTomorrow.count ?? 0,
    endingSoon: endingSoon.count ?? 0,
  };
}

export async function getKitchenQueue(): Promise<KitchenQueueRow[]> {
  if (!hasSupabaseConfig()) return demoQueue;

  const supabase = await createClient();
  const tomorrow = cairoDate(1);

  const { data, error } = await supabase
    .from("production_queue")
    .select(
      "id, production_date, client_name_snapshot, program_name_snapshot, meal_name_snapshot, meal_type, quantity, area_snapshot, delivery_note_snapshot, status, locked",
    )
    .eq("production_date", tomorrow)
    .order("client_name_snapshot", { ascending: true });

  if (error) throw new Error(`تعذر تحميل طابور المطبخ: ${error.message}`);

  return (data ?? []) as KitchenQueueRow[];
}

