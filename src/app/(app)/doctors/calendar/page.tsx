import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "تقويم الأطباء" };
export default function Page() { return renderErpModule("calendar", ["doctors.view", "doctors.manage_availability"], ["doctors.manage_availability"]); }
