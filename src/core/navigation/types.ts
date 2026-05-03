import type { NavigatorScreenParams } from "@react-navigation/native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";

export type RootStackParamList = {
  Splash: undefined;
  Onboarding: undefined;
  Auth: { mode?: "login" | "signup" } | undefined;
  ForgotPassword: undefined;
  ResetPassword: { code?: string } | undefined;
  EmailOtp: { email?: string } | undefined;
  EmailVerificationPending: { email: string };
  UserSetupIntent: undefined;
  UserSetupProfile: { intent?: "park" | "host" } | undefined;
  HostSpaceBasics: { draftId?: string } | undefined;
  HostSpaceAddress: { draftId: string };
  HostSpacePricing: { draftId: string };
  HostSpacePhotos: { draftId: string };
  HostSpaceReview: { draftId: string };
  MainTabs: NavigatorScreenParams<MainTabParamList>;
  Booking: { spotId: string };
  PrivacyPolicy: undefined;
  TermsOfUse: undefined;
};

export type MainTabParamList = {
  Home: undefined;
  Rental: undefined;
  Search: undefined;
  Services: undefined;
  Profile: undefined;
};

export type RootScreenProps<T extends keyof RootStackParamList> = NativeStackScreenProps<
  RootStackParamList,
  T
>;
