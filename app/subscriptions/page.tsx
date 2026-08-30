import { ModuleWorkspace } from "@/components/module-workspace";
import { SecurePage } from "@/components/secure-page";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
export const dynamic = "force-dynamic";
const fields = [
  {
    name: "change_type",
    label: "نوع التعديل",
    type: "select" as const,
    required: true,
    options: [
      { value: "PAUSE", label: "إيقاف مؤقت" },
      { value: "RESUME", label: "استئناف" },
      { value: "SKIP", label: "تخطي" },
      { value: "SWAP", label: "تبديل وجبة" },
      { value: "ADDRESS_CHANGE", label: "تغيير عنوان" },
      { value: "WINDOW_CHANGE", label: "تغيير موعد" },
    ],
  },
  {
    name: "effective_from",
    label: "من تاريخ",
    type: "date" as const,
    required: true,
  },
  { name: "effective_to", label: "حتى تاريخ", type: "date" as const },
  { name: "reason", label: "السبب", type: "textarea" as const, required: true },
];
export default function Page() {
  return (
    <SecurePage
      permission="subscriptions.read"
      title="الاشتراكات والاستحقاقات"
      subtitle="كل تعديل Preview ثم Commit ويعيد بناء الجدول"
    >
      <WorkspaceBoundary>
        <ModuleWorkspace
          model="subscribers"
          metrics={[{ key: "remaining_entitlements", label: "الاستحقاقات المتبقية", format: "number" }, { key: "churn_risk_score", label: "خطر الإلغاء", format: "percent" }]}
          columns={[
            { key: "subscription_number", label: "الاشتراك" },
            { key: "full_name", label: "العميل" },
            { key: "subscription_status", label: "الحالة", format: "status" },
            { key: "plan_name", label: "الخطة" },
            {
              key: "remaining_entitlements",
              label: "الاستحقاقات المتبقية",
              format: "number",
            },
            {
              key: "expected_end_date",
              label: "النهاية المتوقعة",
              format: "date",
            },
            { key: "renewal_due_date", label: "التجديد", format: "date" },
            { key: "pause_until", label: "متوقف حتى", format: "date" },
          ]}
          commands={[
            {
              command: "request_cancellation",
              label: "طلب إلغاء للحسابات",
              rowAction: true,
              tone: "danger",
              prefill: { subscription_id: "subscription_id" },
              fields: [{ name: "subscription_id", label: "رقم الاشتراك", required: true }, { name: "reason", label: "سبب الإلغاء", type: "textarea", required: true }],
            },
            {
              command: "preview_subscription_change",
              label: "معاينة تعديل",
              rowAction: true,
              prefill: { subscription_id: "subscription_id" },
              fields: [
                {
                  name: "subscription_id",
                  label: "رقم الاشتراك",
                  required: true,
                },
                ...fields,
              ],
            },
            {
              command: "commit_subscription_change",
              label: "تنفيذ تعديل",
              rowAction: true,
              prefill: { subscription_id: "subscription_id" },
              fields: [
                {
                  name: "subscription_id",
                  label: "رقم الاشتراك",
                  required: true,
                },
                ...fields,
              ],
            },
          ]}
        />
      </WorkspaceBoundary>
    </SecurePage>
  );
}
