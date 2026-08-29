import { ModuleWorkspace } from "@/components/module-workspace";
import { SecurePage } from "@/components/secure-page";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <SecurePage
      permission="kitchen.demand.read"
      title="المطبخ والجودة"
      subtitle="طلب إنتاج مدفوع فقط — لا تظهر أي بيانات مالية"
    >
      <WorkspaceBoundary>
        <ModuleWorkspace
          model="kitchen_demand"
          metrics={[{ key: "required_quantity", label: "إجمالي المطلوب", format: "number" }, { key: "batched_quantity", label: "دخل الإنتاج", format: "number" }, { key: "shortage_quantity", label: "العجز", format: "number" }]}
          columns={[
            { key: "service_date", label: "اليوم", format: "date" },
            { key: "slot_name", label: "Slot" },
            { key: "meal_name", label: "الصنف" },
            { key: "meal_version", label: "النسخة" },
            { key: "size_code", label: "الحجم" },
            { key: "required_quantity", label: "مطلوب", format: "number" },
            { key: "batched_quantity", label: "داخل Batch", format: "number" },
            { key: "shortage_quantity", label: "عجز", format: "number" },
            { key: "cutoff_status", label: "Cut-off", format: "status" },
          ]}
          commands={[
            {
              command: "create_production_batch",
              label: "إنشاء Batch",
              fields: [
                {
                  name: "service_date",
                  label: "تاريخ الإنتاج",
                  type: "date",
                  required: true,
                },
                {
                  name: "demand_ids",
                  label: "Demand IDs (JSON)",
                  type: "textarea",
                  required: true,
                },
              ],
            },
            {
              command: "release_qa",
              label: "إفراج QA",
              rowAction: true,
              prefill: { batch_id: "batch_id" },
              fields: [
                { name: "batch_id", label: "Batch ID", required: true },
                {
                  name: "result",
                  label: "النتيجة",
                  type: "select",
                  required: true,
                  options: [
                    { value: "PASSED", label: "مقبول" },
                    { value: "FAILED", label: "مرفوض" },
                  ],
                },
                {
                  name: "temperature_c",
                  label: "درجة الحرارة",
                  type: "number",
                  required: true,
                },
                { name: "notes", label: "ملاحظات", type: "textarea" },
              ],
            },
          ]}
        />
      </WorkspaceBoundary>
    </SecurePage>
  );
}
