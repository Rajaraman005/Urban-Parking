import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { Image, StyleSheet, Text, View } from "react-native";

import type { RootStackParamList } from "@/core/navigation/types";
import { AuthBottomSheet, type AuthMode } from "@/features/auth/components/AuthBottomSheet";
import { routeToSetupOrApp } from "@/features/userSetup/services/setupRouting";
import { useAuthStore } from "@/store/authStore";

type Props = NativeStackScreenProps<RootStackParamList, "Auth">;

export function AuthScreen({ navigation, route }: Props) {
  const completeOnboarding = useAuthStore((state) => state.completeOnboarding);
  const refreshSessionOrLogout = useAuthStore((state) => state.refreshSessionOrLogout);
  const mode: AuthMode = route.params?.mode ?? "login";

  const completeAuth = async () => {
    completeOnboarding();
    await refreshSessionOrLogout();
    routeToSetupOrApp(navigation, useAuthStore.getState().profile);
  };

  return (
    <View style={styles.screen}>
      <View style={styles.brand}>
        <Image source={require("../../../assets/logo-mark.png")} resizeMode="contain" style={styles.logo} />
        <Text style={styles.title}>Urban Parking</Text>
      </View>
      <AuthBottomSheet
        mode={mode}
        onClose={() => navigation.replace("Onboarding")}
        onComplete={completeAuth}
        onForgotPassword={() => navigation.navigate("ForgotPassword")}
        onSignupOtpRequired={(email) => navigation.navigate("EmailOtp", { email })}
        visible
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: "#050505"
  },
  brand: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    gap: 12,
    opacity: 0.84
  },
  logo: {
    width: 112,
    height: 112
  },
  title: {
    color: "#FFFFFF",
    fontSize: 24,
    fontWeight: "900"
  }
});
