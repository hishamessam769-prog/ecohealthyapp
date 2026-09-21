import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "الشكاوى" };
export default function Page() { return renderErpModule("complaints", ["complaints.view"], ["complaints.manage"]); }
