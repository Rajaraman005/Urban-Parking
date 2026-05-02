import type { NativeStackNavigationProp } from "@react-navigation/native-stack";

import type { RootStackParamList } from "@/core/navigation/types";
import type { SetupStep, UserProfile } from "@/lib/supabase/database.types";

export type SetupRouteName = Extract<
  keyof RootStackParamList,
  "UserSetupIntent" | "UserSetupProfile" | "HostSpaceBasics" | "HostSpacePricing" | "HostSpacePhotos" | "HostSpaceReview"
>;

const routeByStep: Record<Exclude<SetupStep, "complete">, SetupRouteName> = {
  host_basics: "HostSpaceBasics",
  host_photos: "HostSpacePhotos",
  host_pricing: "HostSpacePricing",
  host_review: "HostSpaceReview",
  intent: "UserSetupIntent",
  profile: "UserSetupProfile"
};

export const isSetupComplete = (profile: UserProfile | null) => Boolean(profile?.onboarding_completed_at);

export const getSetupRouteForProfile = (profile: UserProfile | null): SetupRouteName => {
  if (!profile?.setup_step || profile.setup_step === "complete") {
    return "UserSetupIntent";
  }

  return routeByStep[profile.setup_step];
};

export const routeToSetupOrApp = (
  navigation: Pick<NativeStackNavigationProp<RootStackParamList>, "replace">,
  profile: UserProfile | null
) => {
  if (isSetupComplete(profile)) {
    navigation.replace("MainTabs", { screen: "Home" });
    return;
  }

  const routeName = getSetupRouteForProfile(profile);
  const draftId = profile?.setup_draft_id ?? undefined;

  switch (routeName) {
    case "HostSpacePricing":
    case "HostSpacePhotos":
    case "HostSpaceReview":
      if (draftId) {
        navigation.replace(routeName, { draftId });
        return;
      }
      navigation.replace("HostSpaceBasics", undefined);
      return;
    case "HostSpaceBasics":
      navigation.replace("HostSpaceBasics", draftId ? { draftId } : undefined);
      return;
    case "UserSetupProfile":
      navigation.replace("UserSetupProfile", profile?.intent ? { intent: profile.intent } : undefined);
      return;
    default:
      navigation.replace("UserSetupIntent", undefined);
  }
};
