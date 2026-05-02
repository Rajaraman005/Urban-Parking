import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { StatusBar } from "expo-status-bar";
import { useState } from "react";
import { StyleSheet, Text, useWindowDimensions, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import type { RootStackParamList } from "@/core/navigation/types";
import { AuthBottomSheet, type AuthMode } from "@/features/auth/components/AuthBottomSheet";
import { HeroCarousel } from "@/features/onboarding/components/HeroCarousel";
import { OnboardingActionSheet } from "@/features/onboarding/components/OnboardingActionSheet";
import { onboardingSlides } from "@/features/onboarding/data/onboardingSlides";
import { routeToSetupOrApp } from "@/features/userSetup/services/setupRouting";
import { useAuthStore } from "@/store/authStore";

type Props = NativeStackScreenProps<RootStackParamList, "Onboarding">;

export function OnboardingScreen({ navigation }: Props) {
  const completeOnboarding = useAuthStore((state) => state.completeOnboarding);
  const refreshSessionOrLogout = useAuthStore((state) => state.refreshSessionOrLogout);
  const sessionError = useAuthStore((state) => state.sessionError);
  const insets = useSafeAreaInsets();
  const { height, width } = useWindowDimensions();
  const [authMode, setAuthMode] = useState<AuthMode>("signup");
  const [isAuthVisible, setIsAuthVisible] = useState(false);
  const actionSheetHeight = 190 + Math.max(insets.bottom, 16);
  const heroHeight = Math.max(height - actionSheetHeight + 28, height * 0.68);
  const shouldShowSessionMessage =
    sessionError?.category === "session_expired" || sessionError?.category === "token_reuse_suspected";

  const openAuthSheet = (mode: AuthMode) => {
    setAuthMode(mode);
    setIsAuthVisible(true);
  };

  const completeAuth = async () => {
    completeOnboarding();
    await refreshSessionOrLogout();
    routeToSetupOrApp(navigation, useAuthStore.getState().profile);
  };

  return (
    <View style={{ flex: 1, backgroundColor: "#050505" }}>
      <StatusBar style="light" />
      <HeroCarousel
        bottomOffset={28}
        height={heroHeight}
        slides={onboardingSlides}
        topInset={insets.top}
        width={width}
      />
      <View style={{ position: "absolute", left: 0, right: 0, bottom: 0 }}>
        <OnboardingActionSheet
          bottomInset={insets.bottom}
          height={actionSheetHeight}
          onLogin={() => openAuthSheet("login")}
          onPrivacyPolicy={() => navigation.navigate("PrivacyPolicy")}
          onSignup={() => openAuthSheet("signup")}
          onTermsOfUse={() => navigation.navigate("TermsOfUse")}
        />
      </View>
      {shouldShowSessionMessage ? (
        <View style={[styles.sessionBanner, { top: insets.top + 12 }]}>
          <Text style={styles.sessionBannerText}>{sessionError.message}</Text>
        </View>
      ) : null}
      <AuthBottomSheet
        mode={authMode}
        onClose={() => setIsAuthVisible(false)}
        onComplete={completeAuth}
        onForgotPassword={() => {
          setIsAuthVisible(false);
          navigation.navigate("ForgotPassword");
        }}
        onSignupOtpRequired={(email) => {
          setIsAuthVisible(false);
          navigation.navigate("EmailOtp", { email });
        }}
        visible={isAuthVisible}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  sessionBanner: {
    position: "absolute",
    left: 18,
    right: 18,
    zIndex: 20,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.16)",
    backgroundColor: "rgba(10,10,10,0.78)",
    paddingHorizontal: 16,
    paddingVertical: 12
  },
  sessionBannerText: {
    color: "#FFFFFF",
    fontSize: 13,
    fontWeight: "800",
    lineHeight: 18,
    textAlign: "center"
  }
});
