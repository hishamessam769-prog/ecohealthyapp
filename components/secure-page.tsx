import { AppShell } from "@/components/app-shell";
import { protectPage } from "@/lib/auth";

export async function SecurePage({ permission, title, subtitle, children, actions }: { permission: string; title: string; subtitle: string; children: React.ReactNode; actions?: React.ReactNode }) {
  const principal = await protectPage(permission);
  return <AppShell principal={principal} title={title} subtitle={subtitle} actions={actions}>{children}</AppShell>;
}
