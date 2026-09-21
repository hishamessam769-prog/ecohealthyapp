import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "الإشعارات والتكاملات" };
export default function Page() { return renderErpModule("notifications", ["notifications.view"], ["notifications.view"]); }
