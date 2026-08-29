import type { Principal } from "@/lib/auth";
import { AppError } from "@/lib/errors";
import { createAdminClient } from "@/lib/supabase/admin";

type ModelDefinition = { view: string; permission: string; scope?: "employee" | "rider" | "team"; searchColumn?: string; defaultOrder?: string };

export const readModels = {
  ceo_dashboard: { view: "eco_ceo_dashboard_v", permission: "dashboard.ceo.read", defaultOrder: "freshness" },
  operations_dashboard: { view: "eco_operations_dashboard_v", permission: "dashboard.operations.read", defaultOrder: "freshness" },
  finance_dashboard: { view: "eco_finance_dashboard_v", permission: "dashboard.finance.read", defaultOrder: "freshness" },
  sales_agent_dashboard: { view: "eco_sales_agent_dashboard_v", permission: "dashboard.sales.own", scope: "employee" },
  sales_manager_dashboard: { view: "eco_sales_manager_dashboard_v", permission: "dashboard.sales.team", scope: "team" },
  crm_leads: { view: "eco_crm_leads_v", permission: "crm.read", scope: "employee", searchColumn: "search_text", defaultOrder: "created_at" },
  subscribers: { view: "eco_subscribers_directory_v", permission: "subscribers.read", scope: "employee", searchColumn: "search_text", defaultOrder: "renewal_due_date" },
  customers: { view: "eco_customer_360_v", permission: "customers.read", scope: "employee", searchColumn: "search_text", defaultOrder: "created_at" },
  orders: { view: "eco_orders_v", permission: "orders.read", scope: "employee", searchColumn: "search_text", defaultOrder: "created_at" },
  accounting_queue: { view: "eco_accounting_verification_queue_v", permission: "payments.verify", defaultOrder: "created_at" },
  accounting_close: { view: "eco_accounting_close_blockers_v", permission: "accounting.close", defaultOrder: "severity" },
  kitchen_demand: { view: "eco_kitchen_daily_demand_v", permission: "kitchen.demand.read", defaultOrder: "service_date" },
  kitchen_batches: { view: "eco_kitchen_batches_v", permission: "kitchen.batch.read", defaultOrder: "service_date" },
  inventory: { view: "eco_inventory_stock_v", permission: "inventory.read", searchColumn: "search_text", defaultOrder: "ingredient_name" },
  dispatcher_routes: { view: "eco_dispatcher_routes_v", permission: "routes.manage", defaultOrder: "route_date" },
  rider_route: { view: "eco_rider_today_route_v", permission: "route.own.read", scope: "rider", defaultOrder: "sequence_no" },
  commissions: { view: "eco_commissions_v", permission: "commissions.read", scope: "employee", defaultOrder: "period_start" },
  targets: { view: "eco_targets_v", permission: "targets.read", defaultOrder: "period_start" },
  catalog: { view: "eco_catalog_v", permission: "catalog.read", searchColumn: "search_text", defaultOrder: "package_name" },
  menu: { view: "eco_menu_planner_v", permission: "menu.read", defaultOrder: "service_date" },
  notifications: { view: "eco_notifications_v", permission: "notifications.read", scope: "employee", defaultOrder: "created_at" },
  investor_metrics: { view: "eco_investor_certified_metrics_v", permission: "investor.metrics.read", defaultOrder: "period_start" },
  audit: { view: "eco_audit_v", permission: "audit.read", defaultOrder: "occurred_at" },
  zone_options: { view: "eco_zone_options_v", permission: "customers.create", defaultOrder: "label" },
  employee_options: { view: "eco_employee_options_v", permission: "employees.options.read", defaultOrder: "label" },
  customer_options: { view: "eco_customer_options_v", permission: "orders.create", scope: "employee", defaultOrder: "label" },
  package_options: { view: "eco_package_options_v", permission: "orders.create", defaultOrder: "label" },
  address_options: { view: "eco_address_options_v", permission: "orders.create", scope: "employee", defaultOrder: "label" },
  delivery_window_options: { view: "eco_delivery_window_options_v", permission: "orders.create", defaultOrder: "label" },
  bank_account_options: { view: "eco_bank_account_options_v", permission: "payments.verify", defaultOrder: "label" },
  meal_options: { view: "eco_meal_options_v", permission: "menu.manage", defaultOrder: "label" },
  po_options: { view: "eco_po_options_v", permission: "inventory.receive", defaultOrder: "label" },
} satisfies Record<string, ModelDefinition>;

export type ReadModelName = keyof typeof readModels;

export async function loadReadModel(name: string, principal: Principal, params: URLSearchParams) {
  const definition = readModels[name as ReadModelName] as ModelDefinition | undefined;
  if (!definition) throw new AppError("NOT_FOUND", "نموذج البيانات غير موجود.", 404);
  if (!principal.permissions.includes(definition.permission) && !principal.permissions.includes("*")) throw new AppError("FORBIDDEN", "غير مسموح بعرض هذه البيانات.", 403);
  const page = Math.max(1, Number(params.get("page") ?? "1"));
  const pageSize = Math.min(100, Math.max(10, Number(params.get("pageSize") ?? "25")));
  const admin = createAdminClient();
  let query = admin.from(definition.view).select("*", { count: "exact" });
  if (definition.scope === "employee" && principal.roles.some((role) => ["sales_agent", "cs_agent", "rider"].includes(role))) query = query.eq("scope_employee_id", principal.employeeId);
  if (definition.scope === "rider") query = query.eq("rider_employee_id", principal.employeeId);
  if (definition.scope === "team" && principal.teamIds.length) query = query.in("team_id", principal.teamIds);
  const search = params.get("search")?.trim();
  if (search && definition.searchColumn) query = query.ilike(definition.searchColumn, `%${search.replaceAll("%", "")}%`);
  const dateFrom = params.get("dateFrom");
  const dateTo = params.get("dateTo");
  if (dateFrom) query = query.gte("service_date", dateFrom);
  if (dateTo) query = query.lte("service_date", dateTo);
  const order = definition.defaultOrder ?? "created_at";
  query = query.order(order, { ascending: order === "sequence_no" || order === "service_date" || order === "renewal_due_date" }).range((page - 1) * pageSize, page * pageSize - 1);
  const { data, error, count } = await query;
  if (error) throw new AppError("INTERNAL", "تعذر تحميل البيانات المطلوبة.", 500, { databaseCode: error.code });
  return { rows: data ?? [], page, pageSize, total: count ?? 0, freshness: new Date().toISOString(), model: name };
}
