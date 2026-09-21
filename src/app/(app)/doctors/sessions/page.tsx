import { renderErpModule } from "@/lib/erp/page";
export const metadata = { title: "جلسات الأطباء" };
export default function Page() { return renderErpModule("sessions", ["sessions.view_own", "sessions.view_team"], ["sessions.create"]); }
