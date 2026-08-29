import { ModuleWorkspace } from "@/components/module-workspace";
import { SecurePage } from "@/components/secure-page";
import { WorkspaceBoundary } from "@/components/workspace-boundary";
export const dynamic = "force-dynamic";
export default function Page() {
  return (
    <SecurePage
      permission="audit.read"
      title="سجل التدقيق"
      subtitle="أحداث غير قابلة للتعديل مع actor وسبب وrequest ID"
    >
      <WorkspaceBoundary>
        <ModuleWorkspace
          model="audit"
          columns={[
            { key: "occurred_at", label: "الوقت", format: "datetime" },
            { key: "actor_name", label: "المنفذ" },
            { key: "action", label: "الإجراء" },
            { key: "entity_type", label: "النوع" },
            { key: "entity_id", label: "Entity ID" },
            { key: "request_id", label: "Request ID" },
            { key: "reason", label: "السبب" },
            { key: "source", label: "المصدر" },
          ]}
        />
      </WorkspaceBoundary>
    </SecurePage>
  );
}
