import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "المشروعات" };
export default function Page() { return renderErpModule("projects", ["projects.view", "projects.manage"], ["projects.manage"]); }
