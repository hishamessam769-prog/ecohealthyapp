import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "الأهداف والعمولات" };
export default function Page() { return renderErpModule("performance", ["targets.view_own", "targets.view_team"], ["targets.manage"]); }
