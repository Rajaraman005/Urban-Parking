import { zodResolver } from "@hookform/resolvers/zod";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { useEffect, useState } from "react";
import { Controller, useForm } from "react-hook-form";

import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import type { RootStackParamList } from "@/core/navigation/types";
import { AuthFormLayout } from "@/features/auth/components/AuthFormLayout";
import { passwordUpdateSchema, type PasswordUpdateValues } from "@/features/auth/schemas/authSchemas";
import { toAuthError } from "@/features/auth/services/authErrors";
import { authService } from "@/features/auth/services/authService";
import { useAuthStore } from "@/features/auth/store/authStore";

type Props = NativeStackScreenProps<RootStackParamList, "ResetPassword">;

export function PasswordUpdateScreen({ navigation, route }: Props) {
  const completeOnboarding = useAuthStore((state) => state.completeOnboarding);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [isExchangingCode, setIsExchangingCode] = useState(false);
  const form = useForm<PasswordUpdateValues>({
    defaultValues: { password: "" },
    resolver: zodResolver(passwordUpdateSchema)
  });

  useEffect(() => {
    const code = route.params?.code;

    if (!code) {
      return;
    }

    let isMounted = true;
    setIsExchangingCode(true);

    authService
      .exchangeCodeForSession(code)
      .catch((error) => {
        if (isMounted) {
          setSubmitError(toAuthError(error).message);
        }
      })
      .finally(() => {
        if (isMounted) {
          setIsExchangingCode(false);
        }
      });

    return () => {
      isMounted = false;
    };
  }, [route.params?.code]);

  const onSubmit = form.handleSubmit(async ({ password }) => {
    setSubmitError(null);

    try {
      await authService.updatePassword(password);
      completeOnboarding();
      navigation.replace("MainTabs", { screen: "Home" });
    } catch (error) {
      setSubmitError(toAuthError(error).message);
    }
  });

  return (
    <AuthFormLayout
      description="Choose a strong password before returning to your Urban Parking account."
      error={submitError}
      title="Create new password"
    >
      <Controller
        control={form.control}
        name="password"
        render={({ field, fieldState }) => (
          <Input
            autoComplete="new-password"
            error={fieldState.error?.message}
            label="New password"
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="Minimum 8 characters"
            secureTextEntry
            textContentType="newPassword"
            value={field.value}
          />
        )}
      />
      <Button
        disabled={isExchangingCode}
        label={isExchangingCode ? "Securing reset session" : "Update password"}
        loading={form.formState.isSubmitting || isExchangingCode}
        onPress={onSubmit}
      />
    </AuthFormLayout>
  );
}
