import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "العملاء المحتملون" };
export default function Page() { return renderErpModule("leads", ["leads.view"], ["leads.manage"]); }
