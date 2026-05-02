import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { useEffect, useState } from "react";

import { Button } from "@/components/ui/Button";
import type { RootStackParamList } from "@/core/navigation/types";
import { AuthFormLayout } from "@/features/auth/components/AuthFormLayout";
import { toAuthError } from "@/features/auth/services/authErrors";
import { authService } from "@/features/auth/services/authService";
import { useAuthStore } from "@/features/auth/store/authStore";
import { routeToSetupOrApp } from "@/features/userSetup/services/setupRouting";

type Props = NativeStackScreenProps<RootStackParamList, "EmailVerificationPending">;

const EMAIL_VERIFICATION_RESEND_COOLDOWN_MS = 60_000;

export function EmailVerificationPendingScreen({ navigation, route }: Props) {
  const completeOnboarding = useAuthStore((state) => state.completeOnboarding);
  const refreshSessionOrLogout = useAuthStore((state) => state.refreshSessionOrLogout);
  const setCooldown = useAuthStore((state) => state.setCooldown);
  const cooldownUntil = useAuthStore((state) => state.cooldowns.emailOtpUntil);
  const [now, setNow] = useState(Date.now());
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [isChecking, setIsChecking] = useState(false);
  const cooldownRemaining = Math.max(0, Math.ceil(((cooldownUntil ?? 0) - now) / 1000));
  const email = route.params.email;

  useEffect(() => {
    if (cooldownRemaining <= 0) {
      return undefined;
    }

    const interval = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(interval);
  }, [cooldownRemaining]);

  const checkSession = async () => {
    setSubmitError(null);
    setIsChecking(true);

    try {
      const profile = await authService.ensureProfile();

      if (!profile.email_verified_at) {
        setSubmitError("Your email is not verified yet. Enter the code sent to your inbox.");
        return;
      }

      completeOnboarding();
      await refreshSessionOrLogout();
      routeToSetupOrApp(navigation, useAuthStore.getState().profile);
    } catch (error) {
      setSubmitError(toAuthError(error).message);
    } finally {
      setIsChecking(false);
    }
  };

  const resend = async () => {
    if (cooldownRemaining > 0) {
      setSubmitError(`Please wait ${cooldownRemaining}s before requesting another email.`);
      return;
    }

    setSubmitError(null);

    try {
      await authService.requestSignupOtp();
      setCooldown("emailOtpUntil", Date.now() + EMAIL_VERIFICATION_RESEND_COOLDOWN_MS);
      setNow(Date.now());
      navigation.replace("EmailOtp", { email });
    } catch (error) {
      setSubmitError(toAuthError(error).message);
    }
  };

  return (
    <AuthFormLayout
      description={`We need to verify ${email} with a one-time code before you can list, book, or manage parking spaces.`}
      error={submitError}
      title="Verify your email"
    >
      <Button label="I entered my code" loading={isChecking} onPress={checkSession} />
      <Button
        disabled={cooldownRemaining > 0}
        label={cooldownRemaining > 0 ? `Resend in ${cooldownRemaining}s` : "Send code"}
        variant="secondary"
        onPress={resend}
      />
      <Button label="Back to sign in" variant="ghost" onPress={() => navigation.replace("Onboarding")} />
    </AuthFormLayout>
  );
}
