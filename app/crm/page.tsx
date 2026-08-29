import { ModuleWorkspace } from "@/components/module-workspace";
import { SecurePage } from "@/components/secure-page";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <SecurePage
      permission="crm.read"
      title="CRM والعملاء المحتملون"
      subtitle="من أول تواصل حتى الدفع أو سبب الخسارة"
    >
      <WorkspaceBoundary>
        <ModuleWorkspace
          model="crm_leads"
          metrics={[{ key: "first_response_minutes", label: "متوسط سرعة الرد بالدقائق", format: "number" }]}
          columns={[
            { key: "lead_number", label: "رقم Lead" },
            { key: "full_name", label: "الاسم" },
            { key: "phone_masked", label: "الهاتف" },
            { key: "stage", label: "المرحلة", format: "status" },
            { key: "source_name", label: "المصدر" },
            { key: "assigned_agent", label: "المسؤول" },
            {
              key: "first_response_minutes",
              label: "أول رد بالدقائق",
              format: "number",
            },
            {
              key: "next_action_at",
              label: "الإجراء التالي",
              format: "datetime",
            },
          ]}
          commands={[
            {
              command: "create_lead",
              label: "Lead جديد",
              fields: [
                { name: "full_name", label: "الاسم", required: true },
                { name: "phone", label: "الهاتف", type: "tel", required: true },
                {
                  name: "source_code",
                  label: "المصدر",
                  type: "select",
                  required: true,
                  options: [
                    { value: "WHATSAPP", label: "WhatsApp" },
                    { value: "WEBSITE", label: "Website" },
                    { value: "META", label: "Meta Ads" },
                    { value: "PHONE", label: "مكالمة" },
                    { value: "REFERRAL", label: "ترشيح" },
                    { value: "ORGANIC", label: "Organic" },
                    { value: "MANUAL", label: "إدخال يدوي" },
                  ],
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
