"use server";

import { cookies } from "next/headers";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { getViewer } from "@/lib/auth/viewer";

export async function setActiveBranchAction(formData: FormData) {
  const viewer = await getViewer();
  if (!viewer) redirect("/login");

  const branchId = z.string().uuid().safeParse(formData.get("branchId"));
  const rawReturnPath = String(formData.get("returnPath") || "/dashboard");
  const returnPath = rawReturnPath.startsWith("/") && !rawReturnPath.startsWith("//") ? rawReturnPath : "/dashboard";
  if (!branchId.success || !viewer.branches.some((branch) => branch.id === branchId.data)) {
    redirect(`${returnPath}?error=branch-access`);
  }

  (await cookies()).set("eco_active_branch", branchId.data, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
  });
  revalidatePath("/", "layout");
  redirect(returnPath);
}
