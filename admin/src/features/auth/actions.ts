"use server";

import { redirect } from "next/navigation";
import { z } from "zod";
import { assertSameOrigin, requestIdentity } from "@/server/auth/http";
import { authenticateAdmin } from "@/server/auth/login";
import { loginRateState, normalizeUsername, recordLoginAttempt } from "@/server/auth/rate-limit";
import { clearSessionCookie, revokeCurrentSession } from "@/server/auth/session";

const loginSchema = z.object({
  password: z.string().min(8).max(256),
  username: z.string().min(2).max(120).transform(normalizeUsername)
});

export interface LoginActionState {
  error?: string;
}

export async function loginAction(_state: LoginActionState, formData: FormData): Promise<LoginActionState> {
  await assertSameOrigin();
  const parsed = loginSchema.safeParse({
    password: formData.get("password"),
    username: formData.get("username")
  });

  if (!parsed.success) {
    return { error: "Enter a valid username and password." };
  }

  const identity = await requestIdentity();
  const rateState = await loginRateState(parsed.data.username, identity.ipAddress);
  if (rateState.blocked) {
    await recordLoginAttempt({
      failureReason: "rate_limited",
      ipHash: rateState.ipHash,
      success: false,
      username: parsed.data.username
    });
    return { error: "Too many attempts. Try again later." };
  }

  const result = await authenticateAdmin({
    ipHash: rateState.ipHash,
    password: parsed.data.password,
    userAgent: identity.userAgent,
    username: parsed.data.username
  });

  await recordLoginAttempt({
    failureReason: result.ok ? undefined : result.reason,
    ipHash: rateState.ipHash,
    success: result.ok,
    username: parsed.data.username
  });

  if (!result.ok) {
    return { error: "Username or password is incorrect." };
  }

  redirect("/reviews");
}

export async function logoutAction() {
  await revokeCurrentSession();
  await clearSessionCookie();
  redirect("/login");
}
