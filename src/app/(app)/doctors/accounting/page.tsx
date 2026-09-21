import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "حسابات الأطباء" };
export default function Page() { return renderErpModule("doctorAccounting", ["doctor_commissions.view_own", "doctor_commissions.review"], ["doctor_commissions.review"]); }
