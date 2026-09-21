import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "المهام والمتابعات" };
export default function Page() { return renderErpModule("tasks", ["tasks.view_own", "tasks.view_team", "tasks.view_all", "tasks.view"], ["tasks.create"]); }
