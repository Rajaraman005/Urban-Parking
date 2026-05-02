import { Ionicons } from "@expo/vector-icons";
import { zodResolver } from "@hookform/resolvers/zod";
import { useCallback, useEffect, useRef, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import {
  Animated,
  Easing,
  Keyboard,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import {
  AuthDivider,
  GoogleAuthButton,
  PrimaryAuthButton,
} from "@/features/auth/components/AuthButtons";
import { AuthInputField } from "@/features/auth/components/AuthInputField";
import { OtpCodeInput } from "@/features/auth/components/OtpCodeInput";
import { PasswordStrengthMeter } from "@/features/auth/components/PasswordStrengthMeter";
import {
  loginSchema,
  signupOtpVerifySchema,
  signupSchema,
  type SignupOtpVerifyValues,
} from "@/features/auth/schemas/authSchemas";
import { authService } from "@/features/auth/services/authService";
import { toAuthError } from "@/features/auth/services/authErrors";
import { useAuthStore } from "@/store/authStore";

export type AuthMode = "login" | "signup";
type AuthSheetStep = "credentials" | "otp";

const SHEET_CLOSED_OFFSET = 640;

interface AuthSheetFormValues {
  fullName?: string;
  email: string;
  password: string;
}

const maskEmail = (email: string) => {
  const [name = "", domain = ""] = email.split("@");

  if (!domain) {
    return email;
  }

  const visibleName = name.length <= 2 ? name[0] ?? "" : name.slice(0, 2);

  return `${visibleName}${"*".repeat(Math.max(3, Math.min(6, name.length)))}@${domain}`;
};

interface AuthBottomSheetProps {
  mode: AuthMode;
  onClose: () => void;
  onComplete: () => void | Promise<void>;
  onForgotPassword?: () => void;
  onSignupOtpRequired?: (email: string) => void;
  visible: boolean;
}

export function AuthBottomSheet({
  mode,
  onClose,
  onComplete,
  onForgotPassword,
  visible,
}: AuthBottomSheetProps) {
  const insets = useSafeAreaInsets();
  const cooldownUntil = useAuthStore((state) => state.cooldowns.emailOtpUntil);
  const setCooldown = useAuthStore((state) => state.setCooldown);
  const translateY = useRef(new Animated.Value(SHEET_CLOSED_OFFSET)).current;
  const backdropOpacity = useRef(new Animated.Value(0)).current;
  const contentOpacity = useRef(new Animated.Value(0)).current;
  const contentTranslateY = useRef(new Animated.Value(18)).current;
  const [mounted, setMounted] = useState(visible);
  const [sheetStep, setSheetStep] = useState<AuthSheetStep>("credentials");
  const [otpEmail, setOtpEmail] = useState("");
  const [now, setNow] = useState(Date.now());
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [isSubmittingGoogle, setIsSubmittingGoogle] = useState(false);
  const [isRequestingOtp, setIsRequestingOtp] = useState(false);
  const isSignup = mode === "signup";
  const isOtpStep = sheetStep === "otp";
  const form = useForm<AuthSheetFormValues>({
    defaultValues: {
      fullName: "",
      email: "",
      password: "",
    },
    resolver: zodResolver(isSignup ? signupSchema : loginSchema),
    mode: "onSubmit",
  });
  const otpForm = useForm<SignupOtpVerifyValues>({
    defaultValues: { token: "" },
    resolver: zodResolver(signupOtpVerifySchema),
    mode: "onChange",
  });
  const otpToken = otpForm.watch("token");
  const cooldownRemaining = Math.max(0, Math.ceil(((cooldownUntil ?? 0) - now) / 1000));
  const isBusy = form.formState.isSubmitting || isSubmittingGoogle || isRequestingOtp;
  const isOtpBusy = otpForm.formState.isSubmitting || isRequestingOtp;

  useEffect(() => {
    form.clearErrors();
    otpForm.clearErrors();
    setSubmitError(null);
    setSheetStep("credentials");
    setOtpEmail("");
    form.reset({
      fullName: "",
      email: "",
      password: "",
    });
    otpForm.reset({ token: "" });
  }, [form, mode, otpForm]);

  useEffect(() => {
    if (cooldownRemaining <= 0) {
      return undefined;
    }

    const interval = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(interval);
  }, [cooldownRemaining]);

  useEffect(() => {
    if (visible) {
      setMounted(true);
      translateY.setValue(SHEET_CLOSED_OFFSET);
      backdropOpacity.setValue(0);
      contentOpacity.setValue(0);
      contentTranslateY.setValue(18);

      Animated.parallel([
        Animated.timing(backdropOpacity, {
          toValue: 1,
          duration: 260,
          easing: Easing.out(Easing.cubic),
          useNativeDriver: true,
        }),
        Animated.spring(translateY, {
          toValue: 0,
          damping: 22,
          mass: 0.9,
          stiffness: 190,
          useNativeDriver: true,
        }),
        Animated.sequence([
          Animated.delay(120),
          Animated.parallel([
            Animated.timing(contentOpacity, {
              toValue: 1,
              duration: 320,
              easing: Easing.out(Easing.cubic),
              useNativeDriver: true,
            }),
            Animated.timing(contentTranslateY, {
              toValue: 0,
              duration: 360,
              easing: Easing.out(Easing.cubic),
              useNativeDriver: true,
            }),
          ]),
        ]),
      ]).start();
      return;
    }

    Animated.parallel([
      Animated.timing(backdropOpacity, {
        toValue: 0,
        duration: 180,
        easing: Easing.in(Easing.cubic),
        useNativeDriver: true,
      }),
      Animated.timing(translateY, {
        toValue: SHEET_CLOSED_OFFSET,
        duration: 230,
        easing: Easing.in(Easing.cubic),
        useNativeDriver: true,
      }),
    ]).start(({ finished }) => {
      if (finished) {
        setMounted(false);
      }
    });
  }, [backdropOpacity, contentOpacity, contentTranslateY, translateY, visible]);

  const closeAuthSheet = useCallback(() => {
    Keyboard.dismiss();
    onClose();
  }, [onClose]);

  const returnToCredentials = useCallback(() => {
    Keyboard.dismiss();
    setSubmitError(null);
    setSheetStep("credentials");
    otpForm.reset({ token: "" });
  }, [otpForm]);

  const requestSignupOtp = useCallback(async () => {
    if (cooldownRemaining > 0) {
      setSubmitError(`Please wait ${cooldownRemaining}s before requesting another code.`);
      return false;
    }

    setSubmitError(null);
    setIsRequestingOtp(true);

    try {
      const response = await authService.requestSignupOtp();

      if (response.alreadyVerified) {
        await onComplete();
        return true;
      }

      if (response.resendAvailableAt) {
        setCooldown("emailOtpUntil", new Date(response.resendAvailableAt).getTime());
        setNow(Date.now());
      }

      return true;
    } catch (error) {
      setSubmitError(toAuthError(error).message);
      return false;
    } finally {
      setIsRequestingOtp(false);
    }
  }, [cooldownRemaining, onComplete, setCooldown]);

  const showOtpStep = useCallback(
    async (email: string) => {
      setOtpEmail(email);
      setSheetStep("otp");
      otpForm.reset({ token: "" });
      await requestSignupOtp();
    },
    [otpForm, requestSignupOtp],
  );

  if (!mounted) {
    return null;
  }

  const onSubmit = form.handleSubmit(async (values) => {
    setSubmitError(null);

    try {
      if (isSignup) {
        const data = await authService.signUpWithEmailPassword({
          email: values.email,
          password: values.password,
          fullName: values.fullName ?? "",
        });

        if (!data.session) {
          setSubmitError(
            "Disable Supabase default confirmation email so Urban Parking can send the secure OTP code.",
          );
          return;
        }

        await showOtpStep(values.email);
        return;
      } else {
        const data = await authService.signInWithEmailPassword({
          email: values.email,
          password: values.password,
        });

        if (!data.session) {
          setSubmitError(
            "We could not start a secure session. Please try again.",
          );
          return;
        }

        const profile = await authService.ensureProfile();

        if (!profile.email_verified_at) {
          await showOtpStep(data.user.email ?? values.email);
          return;
        }
      }

      await onComplete();
    } catch (error) {
      setSubmitError(toAuthError(error).message);
    }
  });

  const onGooglePress = async () => {
    setSubmitError(null);
    setIsSubmittingGoogle(true);

    try {
      await authService.signInWithGoogle();
      await onComplete();
    } catch (error) {
      setSubmitError(toAuthError(error).message);
    } finally {
      setIsSubmittingGoogle(false);
    }
  };

  const verifyOtp = otpForm.handleSubmit(async ({ token }) => {
    setSubmitError(null);

    try {
      await authService.verifySignupOtp({ token });
      await onComplete();
    } catch (error) {
      setSubmitError(toAuthError(error).message);
    }
  });

  return (
    <View pointerEvents="box-none" style={StyleSheet.absoluteFill}>
      <Animated.View
        pointerEvents={visible ? "auto" : "none"}
        style={[styles.backdrop, { opacity: backdropOpacity }]}
      >
        <Pressable
          accessibilityLabel="Close auth sheet"
          style={StyleSheet.absoluteFill}
          onPress={closeAuthSheet}
        />
      </Animated.View>
      <View
        pointerEvents="box-none"
        style={styles.keyboardLayer}
      >
        <Animated.View
          style={[
            styles.sheet,
            isOtpStep ? styles.otpSheet : isSignup ? styles.signupSheet : styles.loginSheet,
            {
              paddingBottom: Math.max(insets.bottom + 18, 28),
              transform: [{ translateY }],
            },
          ]}
        >
          <View style={styles.header}>
            <Pressable
              accessibilityLabel={isOtpStep ? "Back to signup" : "Close"}
              accessibilityRole="button"
              hitSlop={8}
              onPress={isOtpStep ? returnToCredentials : closeAuthSheet}
              style={styles.closeButton}
            >
              <Ionicons name={isOtpStep ? "chevron-back" : "close"} size={18} color="#0B0B0C" />
            </Pressable>
            <Text style={styles.headerTitle}>
              {isOtpStep ? "Signup" : isSignup ? "Sign up" : "Login"}
            </Text>
            <View style={styles.headerSpacer} />
          </View>
          <Animated.View
            style={[
              styles.contentLayer,
              {
                opacity: contentOpacity,
                transform: [{ translateY: contentTranslateY }],
              },
            ]}
          >
            {isOtpStep ? (
              <View style={styles.otpFixedContent}>
                  <Text style={styles.otpTitle}>
                    Enter the 6-digit code sent to{"\n"}
                    {maskEmail(otpEmail || "your email")}
                  </Text>
                  <Controller
                    control={otpForm.control}
                    name="token"
                    render={({ field, fieldState }) => (
                      <OtpCodeInput
                        autoFocus
                        error={fieldState.error?.message}
                        onBlur={field.onBlur}
                        onChangeText={field.onChange}
                        value={field.value}
                      />
                    )}
                  />
                  {submitError ? (
                    <Text style={styles.submitError}>{submitError}</Text>
                  ) : null}
                  <PrimaryAuthButton
                    disabled={isOtpBusy || otpToken.length !== 6}
                    label="Continue"
                    loading={otpForm.formState.isSubmitting}
                    onPress={verifyOtp}
                  />
                  <Pressable
                    accessibilityRole="button"
                    disabled={isOtpBusy || cooldownRemaining > 0}
                    hitSlop={8}
                    style={[styles.resendButton, isOtpBusy || cooldownRemaining > 0 ? styles.disabledResend : null]}
                    onPress={requestSignupOtp}
                  >
                    <Text style={styles.resendText}>
                      {cooldownRemaining > 0 ? `Resend code in ${cooldownRemaining}s` : "Resend code"}
                    </Text>
                  </Pressable>
              </View>
            ) : (
              <KeyboardAwareScrollView
                bottomOffset={24}
                bounces={false}
                contentContainerStyle={styles.content}
                extraKeyboardSpace={0}
                keyboardDismissMode={Platform.OS === "android" ? "none" : "interactive"}
                keyboardShouldPersistTaps="always"
                showsVerticalScrollIndicator={false}
                style={styles.scroller}
              >
                  <Text style={styles.title}>
                    {isSignup ? "Create your account" : "Welcome back"}
                  </Text>
                  {isSignup ? (
                    <Controller
                      control={form.control}
                      name="fullName"
                      render={({ field, fieldState }) => (
                        <AuthInputField
                          error={fieldState.error?.message}
                          label="Full name"
                          onBlur={field.onBlur}
                          onChangeText={field.onChange}
                          placeholder="Sushant Singh"
                          textContentType="name"
                          value={field.value}
                        />
                      )}
                    />
                  ) : null}
                  <Controller
                    control={form.control}
                    name="email"
                    render={({ field, fieldState }) => (
                      <AuthInputField
                        autoComplete="off"
                        error={fieldState.error?.message}
                        keyboardType="email-address"
                        label="Email address"
                        onBlur={field.onBlur}
                        onChangeText={field.onChange}
                        placeholder="sushant.singh@example.com"
                        textContentType="none"
                        value={field.value}
                      />
                    )}
                  />
                  <Controller
                    control={form.control}
                    name="password"
                    render={({ field, fieldState }) => (
                      <AuthInputField
                        error={fieldState.error?.message}
                        label="Password"
                        onBlur={field.onBlur}
                        onChangeText={field.onChange}
                        placeholder={
                          isSignup
                            ? "Create a strong password"
                            : "Enter your password"
                        }
                        secureTextEntry
                        textContentType={isSignup ? "newPassword" : "password"}
                        value={field.value}
                      />
                    )}
                  />
                  {isSignup ? (
                    <Controller
                      control={form.control}
                      name="password"
                      render={({ field }) => <PasswordStrengthMeter password={field.value ?? ""} />}
                    />
                  ) : null}
                  {submitError ? (
                    <Text style={styles.submitError}>{submitError}</Text>
                  ) : null}
                  <PrimaryAuthButton
                    disabled={isBusy}
                    label="Continue"
                    loading={form.formState.isSubmitting || isRequestingOtp}
                    onPress={onSubmit}
                  />
                  <AuthDivider />
                  <GoogleAuthButton
                    disabled={isBusy}
                    loading={isSubmittingGoogle}
                    onPress={onGooglePress}
                  />
                  {onForgotPassword && !isSignup ? (
                    <View style={styles.secondaryActions}>
                      <Pressable
                        accessibilityRole="button"
                        hitSlop={8}
                        onPress={onForgotPassword}
                      >
                        <Text style={styles.secondaryActionText}>
                          Forgot password?
                        </Text>
                      </Pressable>
                    </View>
                  ) : null}
              </KeyboardAwareScrollView>
            )}
          </Animated.View>
        </Animated.View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(0,0,0,0.42)",
  },
  keyboardLayer: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: "flex-end",
  },
  sheet: {
    width: "100%",
    borderTopLeftRadius: 30,
    borderTopRightRadius: 30,
    backgroundColor: "#FFFFFF",
    paddingHorizontal: 22,
    paddingTop: 18,
    shadowColor: "#000000",
    shadowOffset: { width: 0, height: -14 },
    shadowOpacity: 0.22,
    shadowRadius: 24,
    elevation: 22,
  },
  loginSheet: {
    minHeight: 528,
  },
  signupSheet: {
    minHeight: 592,
  },
  otpSheet: {
    minHeight: 560,
  },
  header: {
    height: 34,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 8,
  },
  closeButton: {
    width: 30,
    height: 30,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 15,
    backgroundColor: "#F4F4F4",
  },
  headerTitle: {
    color: "#0B0B0C",
    fontSize: 13,
    fontWeight: "900",
  },
  headerSpacer: {
    width: 30,
  },
  content: {
    gap: 15,
    paddingBottom: 12,
  },
  otpContent: {
    gap: 18,
    paddingBottom: 28,
  },
  otpFixedContent: {
    flex: 1,
    gap: 18,
    paddingTop: 4,
    paddingBottom: 28,
  },
  contentLayer: {
    flex: 1,
  },
  scroller: {
    flex: 1,
  },
  title: {
    color: "#0B0B0C",
    fontSize: 24,
    fontWeight: "900",
    lineHeight: 30,
    marginBottom: 2,
  },
  otpTitle: {
    color: "#0B0B0C",
    fontSize: 22,
    fontWeight: "900",
    lineHeight: 28,
    marginBottom: 8,
  },
  submitError: {
    color: "#B42318",
    fontSize: 12,
    fontWeight: "800",
    lineHeight: 17,
  },
  resendButton: {
    minHeight: 28,
    alignItems: "center",
    justifyContent: "center",
  },
  disabledResend: {
    opacity: 0.5,
  },
  resendText: {
    color: "#0B0B0C",
    fontSize: 12,
    fontWeight: "900",
  },
  secondaryActions: {
    minHeight: 24,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 18,
  },
  secondaryActionText: {
    color: "#0B0B0C",
    fontSize: 12,
    fontWeight: "900",
  },
});
