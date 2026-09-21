import "server-only";

import { ModuleScreen } from "@/components/erp/module-screen";
import { requireAnyPermission } from "@/lib/auth/require-permission";
import { getModuleView, type ModuleKey } from "@/lib/erp/modules";

export async function renderErpModule(key: ModuleKey, viewPermissions: string[], actionPermissions: string[]) {
  const viewer = await requireAnyPermission(viewPermissions);
  const view = await getModuleView(viewer, key);
  const canAct = viewer.preview || actionPermissions.some((permission) => viewer.permissions.includes(permission));
  return <ModuleScreen view={view} canAct={canAct} />;
}
