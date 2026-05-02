import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { useState } from "react";

import type { RootStackParamList } from "@/core/navigation/types";
import { ChoiceCard } from "@/features/userSetup/components/ChoiceCard";
import { SetupScaffold } from "@/features/userSetup/components/SetupScaffold";
import { toAuthError } from "@/features/auth/services/authErrors";
import { userSetupService } from "@/features/userSetup/services/userSetupService";
import type { UserIntent } from "@/features/userSetup/types/userSetup.types";

type Props = NativeStackScreenProps<RootStackParamList, "UserSetupIntent">;
const parkingRoleImage = require("../../../assets/onboarding_screen_img/user_role/parking.jpg");
const hostRoleImage = require("../../../assets/onboarding_screen_img/user_role/parking_space.jpg");

export function UserSetupIntentScreen({ navigation }: Props) {
  const [intent, setIntent] = useState<UserIntent>("park");
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);

  const continueSetup = async () => {
    setError(null);
    setIsSaving(true);

    try {
      const result = await userSetupService.saveIntent(intent);
      navigation.replace("UserSetupProfile", {
        intent: result.profile.intent ?? intent,
      });
    } catch (saveError) {
      setError(toAuthError(saveError).message);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <SetupScaffold
      copyAlign="start"
      description="Choose how you want to start. You can switch roles later after verification."
      error={error}
      primaryLabel="Continue"
      primaryLoading={isSaving}
      progress={0.16}
      showAvatar={false}
      title="What brings you here? 🤔"
      onPrimaryPress={continueSetup}
    >
      <ChoiceCard
        description="Find secure parking nearby and book it by the hour, day, or month."
        icon="car-sport-outline"
        imageSource={parkingRoleImage}
        selected={intent === "park"}
        title="Park my vehicle"
        onPress={() => setIntent("park")}
      />
      <ChoiceCard
        description="Turn an unused bay, driveway, basement, or apartment slot into income."
        icon="business-outline"
        imageSource={hostRoleImage}
        selected={intent === "host"}
        title="Rent my space"
        onPress={() => setIntent("host")}
      />
    </SetupScaffold>
  );
}
