import { Ionicons } from "@expo/vector-icons";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import { createNativeStackNavigator } from "@react-navigation/native-stack";

import type { MainTabParamList, RootStackParamList } from "@/core/navigation/types";
import { AuthScreen } from "@/features/auth/screens/AuthScreen";
import { EmailOtpScreen } from "@/features/auth/screens/EmailOtpScreen";
import { EmailVerificationPendingScreen } from "@/features/auth/screens/EmailVerificationPendingScreen";
import { PasswordResetRequestScreen } from "@/features/auth/screens/PasswordResetRequestScreen";
import { PasswordUpdateScreen } from "@/features/auth/screens/PasswordUpdateScreen";
import { BookingScreen } from "@/features/booking/screens/BookingScreen";
import { HomeScreen } from "@/features/home/screens/HomeScreen";
import { PrivacyPolicyScreen } from "@/features/legal/screens/PrivacyPolicyScreen";
import { TermsOfUseScreen } from "@/features/legal/screens/TermsOfUseScreen";
import { ListingScreen } from "@/features/listing/screens/ListingScreen";
import { OnboardingScreen } from "@/features/onboarding/screens/OnboardingScreen";
import { SplashScreen } from "@/features/splash/screens/SplashScreen";
import { HostSpaceBasicsScreen } from "@/features/userSetup/screens/HostSpaceBasicsScreen";
import { HostSpacePhotosScreen } from "@/features/userSetup/screens/HostSpacePhotosScreen";
import { HostSpacePricingScreen } from "@/features/userSetup/screens/HostSpacePricingScreen";
import { HostSpaceReviewScreen } from "@/features/userSetup/screens/HostSpaceReviewScreen";
import { UserSetupIntentScreen } from "@/features/userSetup/screens/UserSetupIntentScreen";
import { UserSetupProfileScreen } from "@/features/userSetup/screens/UserSetupProfileScreen";
import { useAppTheme } from "@/theme/useAppTheme";

const Stack = createNativeStackNavigator<RootStackParamList>();
const Tabs = createBottomTabNavigator<MainTabParamList>();

function MainTabs() {
  const { colors } = useAppTheme();

  return (
    <Tabs.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: colors.text,
        tabBarInactiveTintColor: colors.muted,
        tabBarStyle: {
          backgroundColor: colors.surface,
          borderTopColor: colors.border,
          height: 72,
          paddingBottom: 14,
          paddingTop: 8
        },
        tabBarIcon: ({ color, size }) => {
          const iconName = route.name === "Home" ? "map-outline" : "add-circle-outline";
          return <Ionicons name={iconName} size={size} color={color} />;
        }
      })}
    >
      <Tabs.Screen name="Home" component={HomeScreen} />
      <Tabs.Screen name="Listing" component={ListingScreen} options={{ title: "List" }} />
    </Tabs.Navigator>
  );
}

export function RootNavigator() {
  return (
    <Stack.Navigator
      initialRouteName="Splash"
      screenOptions={{
        headerShown: false,
        animation: "fade_from_bottom"
      }}
    >
      <Stack.Screen name="Splash" component={SplashScreen} />
      <Stack.Screen name="Onboarding" component={OnboardingScreen} />
      <Stack.Screen name="Auth" component={AuthScreen} />
      <Stack.Screen name="ForgotPassword" component={PasswordResetRequestScreen} />
      <Stack.Screen name="ResetPassword" component={PasswordUpdateScreen} />
      <Stack.Screen name="EmailOtp" component={EmailOtpScreen} />
      <Stack.Screen name="EmailVerificationPending" component={EmailVerificationPendingScreen} />
      <Stack.Screen name="UserSetupIntent" component={UserSetupIntentScreen} />
      <Stack.Screen name="UserSetupProfile" component={UserSetupProfileScreen} />
      <Stack.Screen name="HostSpaceBasics" component={HostSpaceBasicsScreen} />
      <Stack.Screen name="HostSpacePricing" component={HostSpacePricingScreen} />
      <Stack.Screen name="HostSpacePhotos" component={HostSpacePhotosScreen} />
      <Stack.Screen name="HostSpaceReview" component={HostSpaceReviewScreen} />
      <Stack.Screen name="MainTabs" component={MainTabs} />
      <Stack.Screen name="Booking" component={BookingScreen} />
      <Stack.Screen name="PrivacyPolicy" component={PrivacyPolicyScreen} />
      <Stack.Screen name="TermsOfUse" component={TermsOfUseScreen} />
    </Stack.Navigator>
  );
}
