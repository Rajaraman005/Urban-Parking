import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { StatusBar } from "expo-status-bar";
import { useEffect } from "react";
import { Image, StyleSheet, Text, View } from "react-native";

import type { RootStackParamList } from "@/core/navigation/types";
import { routeToSetupOrApp } from "@/features/userSetup/services/setupRouting";
import { useAuthStore } from "@/store/authStore";

type Props = NativeStackScreenProps<RootStackParamList, "Splash">;

export function SplashScreen({ navigation }: Props) {
  const initializeAuth = useAuthStore((state) => state.initializeAuth);

  useEffect(() => {
    let isMounted = true;

    const boot = async () => {
      const minimumSplashMs = new Promise((resolve) => setTimeout(resolve, 750));
      await Promise.all([initializeAuth(), minimumSplashMs]);

      if (!isMounted) {
        return;
      }

      const authState = useAuthStore.getState();

      if (authState.status === "authenticated" && authState.session) {
        routeToSetupOrApp(navigation, authState.profile);
        return;
      }

      navigation.replace("Onboarding");
    };

    void boot();

    return () => {
      isMounted = false;
    };
  }, [initializeAuth, navigation]);

  return (
    <View style={styles.screen}>
      <StatusBar backgroundColor="#FFFFFF" style="dark" translucent={false} />
      <View style={styles.content}>
        <Image
          source={require("../../../assets/logo-mark.png")}
          resizeMode="contain"
          style={styles.logo}
        />
        <Text style={styles.title}>Urban Parking</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: "#FFFFFF"
  },
  content: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    gap: 16
  },
  logo: {
    width: 150,
    height: 150
  },
  title: {
    color: "#0B0B0C",
    fontSize: 28,
    fontWeight: "800",
    letterSpacing: 0
  }
});
