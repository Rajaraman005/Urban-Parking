import { zodResolver } from "@hookform/resolvers/zod";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { useCallback, useEffect, useRef, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import { Text } from "react-native";

import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import type { RootStackParamList } from "@/core/navigation/types";
import { AuthFormLayout } from "@/features/auth/components/AuthFormLayout";
import { signupOtpVerifySchema, type SignupOtpVerifyValues } from "@/features/auth/schemas/authSchemas";
import { toAuthError } from "@/features/auth/services/authErrors";
import { authService } from "@/features/auth/services/authService";
import { useAuthStore } from "@/features/auth/store/authStore";
import { routeToSetupOrApp } from "@/features/userSetup/services/setupRouting";
import { useAppTheme } from "@/theme/useAppTheme";

type Props = NativeStackScreenProps<RootStackParamList, "EmailOtp">;

export function EmailOtpScreen({ navigation, route }: Props) {
  const { colors } = useAppTheme();
  const completeOnboarding = useAuthStore((state) => state.completeOnboarding);
  const refreshSessionOrLogout = useAuthStore((state) => state.refreshSessionOrLogout);
  const cooldownUntil = useAuthStore((state) => state.cooldowns.emailOtpUntil);
  const setCooldown = useAuthStore((state) => state.setCooldown);
  const [now, setNow] = useState(Date.now());
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [isRequestingCode, setIsRequestingCode] = useState(false);
  const requestedInitialCode = useRef(false);
  const sessionEmail = useAuthStore((state) => state.user?.email);
  const email = route.params?.email ?? sessionEmail ?? "your email";
  const form = useForm<SignupOtpVerifyValues>({
    defaultValues: { token: "" },
    resolver: zodResolver(signupOtpVerifySchema)
  });
  const cooldownRemaining = Math.max(0, Math.ceil(((cooldownUntil ?? 0) - now) / 1000));

  useEffect(() => {
    if (cooldownRemaining <= 0) {
      return undefined;
    }

    const interval = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(interval);
  }, [cooldownRemaining]);

  const requestSignupOtp = useCallback(async () => {
    if (cooldownRemaining > 0) {
      setSubmitError(`Please wait ${cooldownRemaining}s before requesting another code.`);
      return;
    }

    setSubmitError(null);
    setIsRequestingCode(true);

    try {
      const response = await authService.requestSignupOtp();

      if (response.alreadyVerified) {
        await refreshSessionOrLogout();
        completeOnboarding();
        routeToSetupOrApp(navigation, useAuthStore.getState().profile);
        return;
      }

      if (response.resendAvailableAt) {
        setCooldown("emailOtpUntil", new Date(response.resendAvailableAt).getTime());
        setNow(Date.now());
      }
    } catch (error) {
      setSubmitError(toAuthError(error).message);
    } finally {
      setIsRequestingCode(false);
    }
  }, [completeOnboarding, cooldownRemaining, navigation, refreshSessionOrLogout, setCooldown]);

  useEffect(() => {
    if (requestedInitialCode.current) {
      return;
    }

    requestedInitialCode.current = true;
    void requestSignupOtp();
  }, [requestSignupOtp]);

  const verifyOtp = form.handleSubmit(async ({ token }) => {
    setSubmitError(null);

    try {
      await authService.verifySignupOtp({ token });
      await refreshSessionOrLogout();
      completeOnboarding();
      routeToSetupOrApp(navigation, useAuthStore.getState().profile);
    } catch (error) {
      setSubmitError(toAuthError(error).message);
    }
  });

  return (
    <AuthFormLayout
      description={`Enter the 6-digit code sent to ${email}. It expires in 5 minutes.`}
      error={submitError}
      title="Verify your email"
    >
      <Text style={{ color: colors.muted, fontSize: 13, fontWeight: "700", lineHeight: 18 }}>
        This verification is required before you can list, book, or manage parking spaces.
      </Text>
      <Controller
        control={form.control}
        name="token"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            keyboardType="number-pad"
            label="Verification code"
            maxLength={6}
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="123456"
            textContentType="oneTimeCode"
            value={field.value}
          />
        )}
      />
      <Button label="Verify and continue" loading={form.formState.isSubmitting} onPress={verifyOtp} />
      <Button
        disabled={cooldownRemaining > 0}
        label={cooldownRemaining > 0 ? `Resend in ${cooldownRemaining}s` : "Resend code"}
        loading={isRequestingCode}
        variant="secondary"
        onPress={requestSignupOtp}
      />
    </AuthFormLayout>
  );
}
