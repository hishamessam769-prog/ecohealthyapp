import { ModuleWorkspace } from "@/components/module-workspace";
import { SecurePage } from "@/components/secure-page";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <SecurePage
      permission="commissions.read"
      title="محرك العمولات"
      subtitle="سياسات versioned ومراحل الاستحقاق والـclawback"
    >
      <WorkspaceBoundary>
        <ModuleWorkspace
          model="commissions"
          metrics={[{ key: "booked_value", label: "المبيعات المحجوزة", format: "money" }, { key: "pending_value", label: "تحت الاستحقاق", format: "money" }, { key: "payable_amount", label: "عمولات مستحقة", format: "money" }, { key: "clawback_amount", label: "استردادات العمولات", format: "money" }]}
          columns={[
            { key: "period_start", label: "الشهر", format: "date" },
            { key: "employee_name", label: "الموظف" },
            { key: "target", label: "التارجت", format: "money" },
            { key: "booked_value", label: "مدفوع", format: "money" },
            { key: "pending_value", label: "منتظر الاستحقاق", format: "money" },
            { key: "eligible_value", label: "مؤهل نهائي", format: "money" },
            { key: "booked_achievement", label: "تحقيق مدفوع", format: "percent" },
            { key: "confirmed_achievement", label: "تحقيق مؤهل", format: "percent" },
            { key: "accrued_amount", label: "متراكم", format: "money" },
            { key: "payable_amount", label: "مستحق", format: "money" },
            { key: "paid_amount", label: "مدفوع", format: "money" },
            { key: "clawback_amount", label: "Clawback", format: "money" },
            { key: "maturity_reason", label: "سبب الانتظار" },
          ]}
          commands={[
            {
              command: "save_commission_plan",
              label: "نسخة خطة عمولة",
              fields: [
                { name: "plan_name", label: "اسم الخطة", required: true },
                {
                  name: "sale_type",
                  label: "نوع البيع",
                  type: "select",
                  required: true,
                  options: [
                    { value: "SUBSCRIPTION", label: "اشتراك جديد" },
                    { value: "RENEWAL", label: "تجديد" },
                    { value: "A_LA_CARTE", label: "طلب عادي" },
                    { value: "MANAGER", label: "مدير المبيعات" },
                  ],
                },
                {
                  name: "effective_from",
                  label: "ساري من",
                  type: "date",
                  required: true,
                },
                { name: "effective_to", label: "ساري حتى", type: "date" },
                {
                  name: "maturity_rule",
                  label: "قاعدة الاستحقاق",
                  type: "select",
                  required: true,
                  options: [
                    {
                      value: "BOTH_CONDITIONS_REQUIRED",
                      label: "المدة ونسبة التنفيذ",
                    },
                    { value: "EITHER_CONDITION_REQUIRED", label: "أي شرط" },
                    {
                      value: "FIXED_DAYS_AFTER_PAYMENT",
                      label: "مدة بعد الدفع",
                    },
                    {
                      value: "PERCENTAGE_OF_SUBSCRIPTION_FULFILLED",
                      label: "نسبة تنفيذ",
                    },
                    { value: "DELIVERY_COMPLETED", label: "اكتمال التوصيل" },
                    {
                      value: "MANUAL_FINANCE_APPROVAL",
                      label: "اعتماد مالي يدوي",
                    },
                  ],
                },
                {
                  name: "fixed_maturity_days",
                  label: "أيام الانتظار",
                  type: "number",
                  defaultValue: "5",
                },
                {
                  name: "minimum_fulfilled_percentage",
                  label: "نسبة التنفيذ",
                  type: "number",
                  defaultValue: "50",
                },
                {
                  name: "month_end_minimum_hold_days",
                  label: "حد نهاية الشهر",
                  type: "number",
                  defaultValue: "6",
                },
                {
                  name: "manager_gate_percentage",
                  label: "بوابة المدير %",
                  type: "number",
                  defaultValue: "80",
                },
                {
                  name: "tiers",
                  label: "شرائح التحقيق والعمولة",
                  type: "tiers",
                  required: true,
                },
              ],
            },
          ]}
        />
      </WorkspaceBoundary>
    </SecurePage>
  );
}
