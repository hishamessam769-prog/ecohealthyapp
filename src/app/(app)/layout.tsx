import { redirect } from "next/navigation";
import { AppShell } from "@/components/app-shell";
import { getViewer } from "@/lib/auth/viewer";

export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  const viewer = await getViewer();
  if (!viewer) redirect("/login");
  return <AppShell viewer={viewer}>{children}</AppShell>;
}
