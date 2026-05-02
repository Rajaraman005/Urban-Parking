import { zodResolver } from "@hookform/resolvers/zod";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { useEffect, useState } from "react";
import { Controller, useForm } from "react-hook-form";

import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import type { RootStackParamList } from "@/core/navigation/types";
import { AuthFormLayout } from "@/features/auth/components/AuthFormLayout";
import {
  passwordResetRequestSchema,
  type PasswordResetRequestValues
} from "@/features/auth/schemas/authSchemas";
import { toAuthError } from "@/features/auth/services/authErrors";
import { authService } from "@/features/auth/services/authService";
import { useAuthStore } from "@/features/auth/store/authStore";

type Props = NativeStackScreenProps<RootStackParamList, "ForgotPassword">;

const PASSWORD_RESET_COOLDOWN_MS = 60_000;

export function PasswordResetRequestScreen({ navigation }: Props) {
  const cooldownUntil = useAuthStore((state) => state.cooldowns.passwordResetUntil);
  const setCooldown = useAuthStore((state) => state.setCooldown);
  const [now, setNow] = useState(Date.now());
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const form = useForm<PasswordResetRequestValues>({
    defaultValues: { email: "" },
    resolver: zodResolver(passwordResetRequestSchema)
  });
  const cooldownRemaining = Math.max(0, Math.ceil(((cooldownUntil ?? 0) - now) / 1000));

  useEffect(() => {
    if (cooldownRemaining <= 0) {
      return undefined;
    }

    const interval = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(interval);
  }, [cooldownRemaining]);

  const onSubmit = form.handleSubmit(async ({ email }) => {
    if (cooldownRemaining > 0) {
      setSubmitError(`Please wait ${cooldownRemaining}s before requesting another link.`);
      return;
    }

    setSubmitError(null);
    setSuccessMessage(null);

    try {
      await authService.sendPasswordReset(email);
      setCooldown("passwordResetUntil", Date.now() + PASSWORD_RESET_COOLDOWN_MS);
      setNow(Date.now());
      setSuccessMessage("Check your email for the secure reset link.");
    } catch (error) {
      setSubmitError(toAuthError(error).message);
    }
  });

  return (
    <AuthFormLayout
      description="Send a secure password reset link to your verified email address."
      error={submitError}
      title="Reset password"
    >
      <Controller
        control={form.control}
        name="email"
        render={({ field, fieldState }) => (
          <Input
            autoCapitalize="none"
            autoComplete="email"
            error={fieldState.error?.message}
            keyboardType="email-address"
            label="Email address"
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="sushant.singh@example.com"
            textContentType="emailAddress"
            value={field.value}
          />
        )}
      />
      <Button
        disabled={cooldownRemaining > 0}
        label={cooldownRemaining > 0 ? `Try again in ${cooldownRemaining}s` : "Send reset link"}
        loading={form.formState.isSubmitting}
        onPress={onSubmit}
      />
      {successMessage ? <Button label={successMessage} variant="ghost" onPress={() => navigation.goBack()} /> : null}
    </AuthFormLayout>
  );
}
