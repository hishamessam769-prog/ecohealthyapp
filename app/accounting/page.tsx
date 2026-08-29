import { ModuleWorkspace } from "@/components/module-workspace";
import { SecurePage } from "@/components/secure-page";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <SecurePage
      permission="accounting.access"
      title="الحسابات والإقفال"
      subtitle="Gatekeeper والتحصيلات والتسويات والإيراد المؤجل"
    >
      <div className="space-y-6">
        <WorkspaceBoundary>
          <ModuleWorkspace
            model="accounting_queue"
            rowProofUpload
            metrics={[{ key: "expected_amount", label: "مبالغ تنتظر المراجعة", format: "money" }, { key: "declared_amount", label: "مبالغ معلنة", format: "money" }]}
            columns={[
              { key: "payment_id", label: "Payment ID" },
              { key: "invoice_number", label: "الفاتورة" },
              { key: "customer_name", label: "العميل" },
              { key: "method", label: "الطريقة" },
              { key: "expected_amount", label: "المطلوب", format: "money" },
              { key: "declared_amount", label: "المعلن", format: "money" },
              { key: "reference", label: "المرجع" },
              { key: "proof_status", label: "الإثبات", format: "status" },
              {
                key: "duplicate_reference",
                label: "مرجع مكرر",
                format: "status",
              },
              { key: "created_at", label: "منذ", format: "datetime" },
            ]}
            commands={[
              {
                command: "verify_payment",
                label: "مراجعة واعتماد",
                rowAction: true,
                prefill: { payment_id: "payment_id" },
                fields: [
                  { name: "payment_id", label: "Payment ID", required: true },
                  {
                    name: "amount_received",
                    label: "المبلغ المستلم",
                    type: "number",
                    required: true,
                  },
                  {
                    name: "currency",
                    label: "العملة",
                    defaultValue: "EGP",
                    required: true,
                  },
                  {
                    name: "account_id",
                    label: "الحساب / المحفظة",
                    type: "select",
                    lookup: "bank_account_options",
                    required: true,
                  },
                  { name: "reference", label: "مرجع التحصيل", required: true },
                  { name: "payer", label: "اسم الدافع", required: true },
                  {
                    name: "receipt_date",
                    label: "تاريخ الاستلام",
                    type: "date",
                    required: true,
                  },
                  {
                    name: "exception_note",
                    label: "فرق أو استثناء",
                    type: "textarea",
                  },
                ],
              },
              {
                command: "reject_payment",
                label: "رفض",
                rowAction: true,
                tone: "danger",
                prefill: { payment_id: "payment_id" },
                fields: [
                  { name: "payment_id", label: "Payment ID", required: true },
                  {
                    name: "reason",
                    label: "سبب الرفض",
                    type: "textarea",
                    required: true,
                  },
                ],
              },
              {
                command: "receive_cash",
                label: "استلام عهدة Cash",
                fields: [
                  { name: "handover_id", label: "رقم العهدة", required: true },
                  {
                    name: "amount_received",
                    label: "المبلغ المعدود",
                    type: "number",
                    required: true,
                  },
                  {
                    name: "difference_reason",
                    label: "سبب الفرق إن وجد",
                    type: "textarea",
                  },
                ],
              },
            ]}
          />
        </WorkspaceBoundary>
        <WorkspaceBoundary>
          <ModuleWorkspace
            model="accounting_close"
            allowExport={false}
            columns={[
              { key: "blocker_type", label: "معوق الإقفال" },
              { key: "reference", label: "المرجع" },
              { key: "amount", label: "المبلغ", format: "money" },
              { key: "severity", label: "الأهمية", format: "status" },
              { key: "owner_name", label: "المسؤول" },
              { key: "opened_at", label: "منذ", format: "datetime" },
            ]}
          />
        </WorkspaceBoundary>
      </div>
    </SecurePage>
  );
}
