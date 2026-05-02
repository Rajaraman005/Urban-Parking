import { NavigationContainer, DefaultTheme, DarkTheme } from "@react-navigation/native";
import * as SplashScreen from "expo-splash-screen";
import { useEffect, useMemo, type PropsWithChildren } from "react";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { KeyboardProvider } from "react-native-keyboard-controller";
import { SafeAreaProvider } from "react-native-safe-area-context";

import { env } from "@/config/env";
import { setApiTokenProvider } from "@/services/api/apiClient";
import { useAuthStore } from "@/store/authStore";
import { useAppTheme } from "@/theme/useAppTheme";

void SplashScreen.preventAutoHideAsync();

export function AppProvider({ children }: PropsWithChildren) {
  const theme = useAppTheme();
  const getAccessToken = useAuthStore((state) => state.getAccessToken);
  const linking = useMemo(
    () => ({
      prefixes: [`${env.authRedirectScheme}://`],
      config: {
        screens: {
          Auth: "auth",
          EmailOtp: "auth/otp",
          EmailVerificationPending: "auth/verify",
          ForgotPassword: "auth/forgot",
          ResetPassword: "auth/reset"
        }
      }
    }),
    []
  );

  useEffect(() => {
    setApiTokenProvider(getAccessToken);
    void SplashScreen.hideAsync();
  }, [getAccessToken]);

  const navigationTheme = {
    ...(theme.isDark ? DarkTheme : DefaultTheme),
    colors: {
      ...(theme.isDark ? DarkTheme.colors : DefaultTheme.colors),
      background: theme.colors.background,
      card: theme.colors.surface,
      text: theme.colors.text,
      border: theme.colors.border,
      primary: theme.colors.primary
    }
  };

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <KeyboardProvider>
        <SafeAreaProvider>
          <NavigationContainer linking={linking} theme={navigationTheme}>
            {children}
          </NavigationContainer>
        </SafeAreaProvider>
      </KeyboardProvider>
    </GestureHandlerRootView>
  );
}
