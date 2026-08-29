import { AppShell } from "@/components/app-shell";
import { ModuleWorkspace } from "@/components/module-workspace";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
import { protectPage } from "@/lib/auth";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const principal = await protectPage("dashboard.access");
  const investor = principal.roles.includes("investor_readonly");
  const salesManager = principal.roles.includes("sales_manager");
  const salesAgent = principal.roles.includes("sales_agent");
  const finance = principal.roles.some((role)=>["finance_controller","accountant"].includes(role));
  const operations = principal.roles.some((role)=>["operations_manager","kitchen_planner","kitchen_operator","qa_officer","logistics_manager","dispatcher","rider"].includes(role));
  const model = investor ? "investor_metrics" : salesManager ? "sales_manager_dashboard" : salesAgent ? "sales_agent_dashboard" : finance ? "finance_dashboard" : operations ? "operations_dashboard" : "ceo_dashboard";
  const metrics = investor ? [{key:"mrr",label:"MRR",format:"money" as const},{key:"arr",label:"ARR",format:"money" as const},{key:"logo_retention",label:"الاحتفاظ",format:"percent" as const},{key:"contribution_margin",label:"هامش المساهمة",format:"percent" as const}] : salesAgent ? [{key:"target",label:"الهدف",format:"money" as const},{key:"booked_paid",label:"مدفوع / محجوز",format:"money" as const},{key:"confirmed_eligible",label:"مؤكد للعمولة",format:"money" as const},{key:"estimated_commission",label:"عمولة تقديرية",format:"money" as const}] : finance ? [{key:"verified_collections",label:"تحصيلات معتمدة",format:"money" as const},{key:"deferred_revenue",label:"إيراد مؤجل",format:"money" as const},{key:"unallocated_payments",label:"دفعات غير موزعة",format:"number" as const},{key:"open_blockers",label:"معوقات الإقفال",format:"number" as const}] : operations ? [{key:"production_demand",label:"طلب الإنتاج",format:"number" as const},{key:"kitchen_utilization",label:"استخدام الطاقة",format:"percent" as const},{key:"delivery_sla",label:"SLA التوصيل",format:"percent" as const},{key:"open_exceptions",label:"استثناءات مفتوحة",format:"number" as const}] : [{key:"active_members",label:"مشتركون نشطون",format:"number" as const},{key:"recognized_revenue",label:"الإيراد المعترف",format:"money" as const},{key:"mrr",label:"MRR",format:"money" as const},{key:"confirmed_sales",label:"مبيعات مؤكدة",format:"money" as const},{key:"renewal_rate",label:"نسبة التجديد",format:"percent" as const},{key:"logo_churn",label:"Churn",format:"percent" as const},{key:"contribution_margin",label:"هامش المساهمة",format:"percent" as const},{key:"delivery_sla",label:"SLA التوصيل",format:"percent" as const}];
  return <AppShell principal={principal} title="لوحة التحكم" subtitle="أرقام حية حسب صلاحيتك — اضغط على أي قسم للتفاصيل"><WorkspaceBoundary><ModuleWorkspace model={model} columns={metrics} metrics={metrics} allowExport={false}/></WorkspaceBoundary></AppShell>;
}
