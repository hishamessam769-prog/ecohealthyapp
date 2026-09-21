import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "دليل الأطباء" };
export default function Page() { return renderErpModule("doctors", ["doctors.view"], ["doctors.manage"]); }
