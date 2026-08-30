import { ModuleWorkspace } from "@/components/module-workspace";
import { SecurePage } from "@/components/secure-page";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <SecurePage
      permission="customers.read"
      title="سجل العملاء والمشتركين"
      subtitle="المصدر الموحد لبيانات العميل قبل إنشاء أي اشتراك أو فاتورة"
    >
      <WorkspaceBoundary>
        <ModuleWorkspace
          model="customer_directory"
          exportModel="customer_export"
          metrics={[{ key: "active_subscription_count", label: "اشتراكات نشطة", format: "number" }, { key: "total_orders", label: "إجمالي الطلبات", format: "number" }]}
          columns={[
            { key: "customer_number", label: "رقم العميل" },
            { key: "full_name", label: "العميل" },
            { key: "phone", label: "الهاتف" },
            { key: "address_line", label: "العنوان" },
            { key: "zone_name", label: "المنطقة" },
            { key: "delivery_window_name", label: "موعد التوصيل", hiddenMobile: true },
            { key: "sales_owner_name", label: "مسؤول المبيعات" },
            { key: "current_plan_name", label: "الاشتراك الحالي" },
            { key: "active_subscription_count", label: "نشط", format: "number" },
            { key: "map_url", label: "اللوكيشن", format: "link", hiddenMobile: true },
          ]}
          commands={[
            {
              command: "create_customer",
              label: "عميل جديد",
              fields: [
                { name: "full_name", label: "الاسم", required: true },
                { name: "phone", label: "الهاتف", type: "tel", required: true },
                { name: "email", label: "البريد", type: "email" },
                {
                  name: "zone_id",
                  label: "المنطقة",
                  type: "select",
                  lookup: "zone_options",
                  required: true,
                },
                { name: "address_line", label: "العنوان", required: true },
                { name: "map_url", label: "رابط Google Maps", placeholder: "https://maps.google.com/..." },
                { name: "latitude", label: "خط العرض", type: "number", placeholder: "30.0444" },
                { name: "longitude", label: "خط الطول", type: "number", placeholder: "31.2357" },
                {
                  name: "delivery_window_id",
                  label: "موعد التوصيل المفضل",
                  type: "select",
                  lookup: "delivery_window_options",
                },
                {
                  name: "sales_owner_id",
                  label: "مسؤول المبيعات",
                  type: "select",
                  lookup: "employee_options",
                },
                {
                  name: "dietary_notes",
                  label: "المحاذير والتفضيلات",
                  type: "textarea",
                },
              ],
            },
          ]}
        />
      </WorkspaceBoundary>
    </SecurePage>
  );
}
