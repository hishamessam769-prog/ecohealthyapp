import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "العملاء" };
export default function Page() { return renderErpModule("customers", ["customers.view"], ["customers.manage"]); }
