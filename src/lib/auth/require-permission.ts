import "server-only";

import { notFound, redirect } from "next/navigation";
import { getViewer } from "@/lib/auth/viewer";

export async function requirePermission(permission: string) {
  const viewer = await getViewer();
  if (!viewer) redirect("/login");
  if (!viewer.permissions.includes(permission)) notFound();
  return viewer;
}

export async function requireAnyPermission(permissions: string[]) {
  const viewer = await getViewer();
  if (!viewer) redirect("/login");
  if (!permissions.some((permission) => viewer.permissions.includes(permission))) notFound();
  return viewer;
}
