import { SecurePage } from "@/components/secure-page"; import { AdminWorkspace } from "@/components/workspaces/admin-workspace";
export const dynamic="force-dynamic";
export default function Page(){return <SecurePage permission="employees.invite" title="إدارة النظام" subtitle="دعوات الموظفين والأدوار الفعالة والبيئة التجريبية"><AdminWorkspace/></SecurePage>}
