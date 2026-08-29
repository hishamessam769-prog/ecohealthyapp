import { z } from "zod";
import { apiError, ok, parseJson } from "@/lib/api";
import { requirePermission } from "@/lib/auth";
import { AppError } from "@/lib/errors";
import { createAdminClient } from "@/lib/supabase/admin";

const schema = z.object({ email: z.string().email(), fullName: z.string().min(3).max(160), roleCodes: z.array(z.string().min(2)).min(1), teamIds: z.array(z.string().uuid()).default([]) });

export async function POST(request: Request) {
  try {
    const principal = await requirePermission("employees.invite");
    const parsed = schema.safeParse(await parseJson(request));
    if (!parsed.success) throw new AppError("VALIDATION", "بيانات الدعوة غير مكتملة.", 422, parsed.error.flatten());
    const admin = createAdminClient();
    const { data: invite, error } = await admin.auth.admin.inviteUserByEmail(parsed.data.email, { data: { invited_by_employee_id: principal.employeeId } });
    if (error) throw new AppError("VALIDATION", error.message, 422);
    const { data, error: dbError } = await admin.rpc("eco_create_employee_invitation", { p_actor_id: principal.employeeId, p_auth_user_id: invite.user?.id ?? null, p_payload: parsed.data });
    if (dbError) throw dbError;
    return ok(data, 201);
  } catch (cause) { return apiError(cause, { route: "employee_invitation" }); }
}
