import { ModuleWorkspace } from "@/components/module-workspace";
import { SecurePage } from "@/components/secure-page";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <SecurePage
      permission="catalog.read"
      title="الكتالوج والتسعير"
      subtitle="نسخ الباكدجات والأسعار والسياسات حسب تاريخ السريان"
    >
      <WorkspaceBoundary>
        <ModuleWorkspace
          model="catalog"
          columns={[
            { key: "package_code", label: "الكود" },
            { key: "package_name", label: "الباكدج" },
            { key: "program_code", label: "البرنامج" },
            { key: "package_type_code", label: "النوع" },
            { key: "size_code", label: "الحجم" },
            { key: "service_days", label: "أيام الخدمة", format: "number" },
            { key: "meal_slots", label: "الوجبات" },
            { key: "frequency_policy", label: "التكرار" },
            { key: "price", label: "السعر", format: "money" },
            { key: "effective_from", label: "ساري من", format: "date" },
            { key: "status", label: "الحالة", format: "status" },
          ]}
          commands={[{
            command: "save_catalog_price",
            label: "إضافة باكدج وسعر",
            fields: [
              { name: "program_code", label: "البرنامج", type: "select", required: true, options: [{ value: "WEIGHT_LOSS", label: "Weight Loss" }, { value: "MUSCLE_GAIN", label: "Muscle Gain" }] },
              { name: "package_type_code", label: "نوع الباكدج", type: "select", required: true, options: [{ value: "LUNCH_ONLY", label: "Lunch Only" }, { value: "AM", label: "AM Package" }, { value: "BM", label: "BM Package" }, { value: "FULL_DAY", label: "Full Day" }] },
              { name: "service_days", label: "عدد الأيام", type: "select", required: true, options: [{ value: "6", label: "6 أيام" }, { value: "12", label: "12 يومًا" }, { value: "18", label: "18 يومًا" }, { value: "24", label: "24 يومًا" }] },
              { name: "size_code", label: "الحجم", type: "select", required: true, options: [{ value: "REGULAR", label: "Regular" }, { value: "HERO", label: "Hero" }] },
              { name: "price", label: "السعر بالجنيه", type: "number", required: true },
              { name: "tax_rate", label: "الضريبة %", type: "number", defaultValue: "0" },
              { name: "effective_from", label: "ساري من", type: "date", required: true },
            ],
          }, {
            command: "save_sales_policy",
            label: "تحديد حد الخصم",
            fields: [{ name: "max_sales_discount_percentage", label: "أقصى خصم يسمح به للمبيعات %", type: "number", required: true, defaultValue: "10" }],
          }]}
        />
      </WorkspaceBoundary>
    </SecurePage>
  );
}
