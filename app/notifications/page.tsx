import { ModuleWorkspace } from "@/components/module-workspace";
import { SecurePage } from "@/components/secure-page";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <SecurePage
      permission="notifications.read"
      title="المهام والتنبيهات"
      subtitle="تنبيهات شخصية مرتبطة بعميل أو إجراء وتاريخ استحقاق"
    >
      <WorkspaceBoundary>
        <ModuleWorkspace
          model="notifications"
          allowExport={false}
          columns={[
            { key: "title", label: "التنبيه" },
            { key: "body", label: "التفاصيل" },
            { key: "priority", label: "الأولوية", format: "status" },
            { key: "due_at", label: "مطلوب قبل", format: "datetime" },
            { key: "status", label: "الحالة", format: "status" },
            { key: "comment_count", label: "التعليقات", format: "number" },
            { key: "latest_comment", label: "آخر تعليق" },
            { key: "created_at", label: "وصل", format: "datetime" },
          ]}
          commands={[
            {
              command: "add_notification_comment",
              label: "إضافة تعليق",
              rowAction: true,
              prefill: { notification_id: "id" },
              fields: [
                { name: "notification_id", label: "رقم التنبيه", required: true },
                { name: "body", label: "التعليق", type: "textarea", required: true },
              ],
            },
            {
              command: "mark_notification_read",
              label: "قرأت",
              rowAction: true,
              prefill: { notification_id: "id" },
              fields: [
                {
                  name: "notification_id",
                  label: "Notification ID",
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
