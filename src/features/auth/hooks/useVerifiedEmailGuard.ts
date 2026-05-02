import { AppAuthError } from "@/features/auth/services/authErrors";
import { useAuthSession } from "@/features/auth/hooks/useAuthSession";
import { useAuthStore } from "@/features/auth/store/authStore";

const hasVerifiedEmailForApp = () => {
  const latest = useAuthStore.getState();
  const provider = typeof latest.user?.app_metadata?.provider === "string" ? latest.user.app_metadata.provider : undefined;

  return Boolean(latest.profile?.email_verified_at || (provider === "google" && latest.user?.email_confirmed_at));
};

export function useVerifiedEmailGuard() {
  const { isAuthenticated, isEmailVerified, refreshSessionOrLogout } = useAuthSession();

  return {
    canUseMarketplaceActions: isAuthenticated && isEmailVerified,
    ensureVerifiedEmail: async () => {
      await refreshSessionOrLogout();
      const latest = useAuthStore.getState();

      if (latest.status !== "authenticated" || !hasVerifiedEmailForApp()) {
        throw new AppAuthError("auth", "Verify your email before listing or booking parking spaces.");
      }
    },
    isEmailVerified
  };
}
