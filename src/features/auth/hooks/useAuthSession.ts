import { useMemo } from "react";

import { useAuthStore } from "@/features/auth/store/authStore";

export function useAuthSession() {
  const session = useAuthStore((state) => state.session);
  const user = useAuthStore((state) => state.user);
  const profile = useAuthStore((state) => state.profile);
  const status = useAuthStore((state) => state.status);
  const sessionError = useAuthStore((state) => state.sessionError);
  const isHydrating = useAuthStore((state) => state.isHydrating);
  const refreshSessionOrLogout = useAuthStore((state) => state.refreshSessionOrLogout);
  const signOut = useAuthStore((state) => state.signOut);
  const provider = typeof user?.app_metadata?.provider === "string" ? user.app_metadata.provider : undefined;
  const isEmailVerified = Boolean(profile?.email_verified_at || (provider === "google" && user?.email_confirmed_at));

  return useMemo(
    () => ({
      isAuthenticated: status === "authenticated" && Boolean(session),
      isEmailVerified,
      isHydrating,
      profile,
      refreshSessionOrLogout,
      session,
      sessionError,
      signOut,
      status,
      user
    }),
    [isEmailVerified, isHydrating, profile, refreshSessionOrLogout, session, sessionError, signOut, status, user]
  );
}
