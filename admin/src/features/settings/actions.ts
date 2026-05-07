"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { assertSameOrigin } from "@/server/auth/http";
import { assertValidCsrfToken, requireAdmin } from "@/server/auth/session";
import { changeAdminPassword, revokeOtherSessions } from "./repository";

const passwordSchema = z.object({
  csrfToken: z.string().min(20),
  currentPassword: z.string().min(8).max(256),
  newPassword: z.string().min(12).max(256)
});

function stringFrom(formData: FormData, key: string) {
  const value = formData.get(key);
  return typeof value === "string" ? value : "";
}

export async function changePasswordAction(formData: FormData) {
  await assertSameOrigin();
  const session = await requireAdmin();
  await assertValidCsrfToken(stringFrom(formData, "csrfToken"));
  const input = passwordSchema.parse({
    csrfToken: stringFrom(formData, "csrfToken"),
    currentPassword: stringFrom(formData, "currentPassword"),
    newPassword: stringFrom(formData, "newPassword")
  });
  await changeAdminPassword({
    adminUserId: session.admin.id,
    currentPassword: input.currentPassword,
    newPassword: input.newPassword
  });
  revalidatePath("/settings");
  redirect("/settings?toast=password");
}

export async function revokeOtherSessionsAction(formData: FormData) {
  await assertSameOrigin();
  const session = await requireAdmin();
  await assertValidCsrfToken(stringFrom(formData, "csrfToken"));
  await revokeOtherSessions(session.admin.id, session.id);
  revalidatePath("/settings");
  redirect("/settings?toast=sessions");
}
