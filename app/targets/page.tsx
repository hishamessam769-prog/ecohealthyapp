import { ModuleWorkspace } from "@/components/module-workspace";
import { SecurePage } from "@/components/secure-page";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <SecurePage
      permission="targets.read"
      title="الأهداف والخطة"
      subtitle="Original Plan وActual وForecast بدون تعديل النسخ المعتمدة"
    >
      <WorkspaceBoundary>
        <ModuleWorkspace
          model="targets"
          columns={[
            { key: "period_start", label: "الفترة", format: "date" },
            { key: "scope_type", label: "النطاق" },
            { key: "scope_name", label: "الجهة" },
            { key: "revenue_target", label: "هدف الإيراد", format: "money" },
            { key: "booked_actual", label: "مدفوع", format: "money" },
            { key: "confirmed_actual", label: "مؤكد", format: "money" },
            { key: "forecast", label: "Forecast", format: "money" },
            { key: "variance", label: "الفرق", format: "money" },
            { key: "rag_status", label: "الحالة", format: "status" },
          ]}
          commands={[
            {
              command: "save_target",
              label: "هدف جديد / Reforecast",
              fields: [
                {
                  name: "scope_type",
                  label: "النطاق",
                  type: "select",
                  required: true,
                  options: [
                    { value: "COMPANY", label: "الشركة" },
                    { value: "TEAM", label: "فريق" },
                    { value: "EMPLOYEE", label: "موظف" },
                  ],
                },
                {
                  name: "scope_id",
                  label: "الموظف / الفريق",
                  type: "select",
                  lookup: "employee_options",
                },
                {
                  name: "period_start",
                  label: "بداية الشهر",
                  type: "date",
                  required: true,
                },
                {
                  name: "revenue_target",
                  label: "هدف الإيراد",
                  type: "number",
                  required: true,
                },
                { name: "quantity_target", label: "هدف العدد", type: "number" },
                {
                  name: "status",
                  label: "الحالة",
                  type: "select",
                  options: [
                    { value: "DRAFT", label: "مسودة" },
                    { value: "APPROVED", label: "اعتماد" },
                  ],
                },
              ],
            },
          ]}
        />
      </WorkspaceBoundary>
    </SecurePage>
  );
}
