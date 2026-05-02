import { zodResolver } from "@hookform/resolvers/zod";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import type * as ImagePicker from "expo-image-picker";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { Controller, useForm } from "react-hook-form";

import { Input } from "@/components/ui/Input";
import type { RootStackParamList } from "@/core/navigation/types";
import { toAuthError } from "@/features/auth/services/authErrors";
import { useAuthStore } from "@/features/auth/store/authStore";
import { profileSetupSchema, type ProfileSetupValues } from "@/features/userSetup/schemas/userSetupSchemas";
import { SetupScaffold } from "@/features/userSetup/components/SetupScaffold";
import { userSetupService } from "@/features/userSetup/services/userSetupService";
import type { UserIntent } from "@/features/userSetup/types/userSetup.types";
import type { UserProfile } from "@/lib/supabase/database.types";

type Props = NativeStackScreenProps<RootStackParamList, "UserSetupProfile">;
type ProfileGender = ProfileSetupValues["gender"];

const isProfileGender = (value: UserProfile["gender"]): value is ProfileGender =>
  value === "male" || value === "female" || value === "other" || value === "prefer_not_to_say";

const formatDobForInput = (dob?: string | null) => {
  if (!dob) {
    return "";
  }

  const [year, month, day] = dob.split("-");

  return year && month && day ? `${day}/${month}/${year}` : "";
};

const profileToFormValues = (profile: UserProfile): ProfileSetupValues => ({
  dob: formatDobForInput(profile.dob),
  fullName: profile.full_name ?? "",
  gender: isProfileGender(profile.gender) ? profile.gender : "prefer_not_to_say",
  phone: profile.phone ?? ""
});

export function UserSetupProfileScreen({ navigation, route }: Props) {
  const profile = useAuthStore((state) => state.profile);
  const reloadProfile = useAuthStore((state) => state.reloadProfile);
  const refreshSessionOrLogout = useAuthStore((state) => state.refreshSessionOrLogout);
  const intent = useMemo<UserIntent>(() => route.params?.intent ?? profile?.intent ?? "park", [profile?.intent, route.params?.intent]);
  const [error, setError] = useState<string | null>(null);
  const [avatarError, setAvatarError] = useState<string | null>(null);
  const [avatarPreviewUri, setAvatarPreviewUri] = useState<string | null>(null);
  const [isAvatarUploading, setIsAvatarUploading] = useState(false);
  const avatarUploadSequenceRef = useRef(0);
  const form = useForm<ProfileSetupValues>({
    defaultValues: {
      dob: profile ? formatDobForInput(profile.dob) : "",
      fullName: profile?.full_name ?? "",
      gender: profile && isProfileGender(profile.gender) ? profile.gender : "prefer_not_to_say",
      phone: profile?.phone ?? ""
    },
    resolver: zodResolver(profileSetupSchema)
  });

  useEffect(() => {
    if (profile) {
      form.reset(profileToFormValues(profile));
    }
  }, [form, profile]);

  useEffect(() => {
    let isMounted = true;

    const hydrateLatestProfile = async () => {
      try {
        const latestProfile = await reloadProfile();

        if (isMounted && latestProfile) {
          form.reset(profileToFormValues(latestProfile));
        }
      } catch (profileError) {
        if (isMounted) {
          setError(toAuthError(profileError).message);
        }
      }
    };

    void hydrateLatestProfile();

    return () => {
      isMounted = false;
    };
  }, [form, reloadProfile]);

  const handleAvatarPicked = useCallback(
    async (asset: ImagePicker.ImagePickerAsset) => {
      const sequence = Math.max(avatarUploadSequenceRef.current + 1, Date.now());
      avatarUploadSequenceRef.current = sequence;
      setAvatarError(null);
      setAvatarPreviewUri(asset.uri);
      setIsAvatarUploading(true);

      try {
        await userSetupService.uploadProfileAvatar(asset, sequence);

        if (avatarUploadSequenceRef.current !== sequence) {
          return;
        }

        await reloadProfile();
        setAvatarPreviewUri(null);
      } catch (uploadError) {
        if (avatarUploadSequenceRef.current !== sequence) {
          return;
        }

        setAvatarPreviewUri(null);
        setAvatarError(toAuthError(uploadError).message);
      } finally {
        if (avatarUploadSequenceRef.current === sequence) {
          setIsAvatarUploading(false);
        }
      }
    },
    [reloadProfile]
  );

  const submit = form.handleSubmit(async (values) => {
    if (isAvatarUploading) {
      return;
    }

    setError(null);

    try {
      const result = await userSetupService.saveProfile(values, intent);
      await reloadProfile();

      if (intent === "host" && result.draft) {
        navigation.replace("HostSpaceBasics", { draftId: result.draft.id });
        return;
      }

      await refreshSessionOrLogout();
      navigation.replace("MainTabs", { screen: "Home" });
    } catch (saveError) {
      setError(toAuthError(saveError).message);
    }
  });

  return (
    <SetupScaffold
      avatarError={avatarError}
      avatarPreviewUri={avatarPreviewUri}
      avatarUrl={profile?.avatar_url ?? null}
      description="Use real contact details so booking confirmations, host calls, and safety checks work reliably."
      error={error}
      isAvatarUploading={isAvatarUploading}
      primaryLabel={intent === "host" ? "Start listing" : "Enter app"}
      primaryLoading={form.formState.isSubmitting}
      primaryDisabled={isAvatarUploading}
      progress={intent === "host" ? 0.32 : 0.86}
      title="Set up your profile"
      onAvatarError={setAvatarError}
      onAvatarPicked={handleAvatarPicked}
      onBack={() => navigation.replace("UserSetupIntent")}
      onPrimaryPress={submit}
    >
      <Controller
        control={form.control}
        name="fullName"
        render={({ field, fieldState }) => (
          <Input
            autoCapitalize="words"
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
      <Controller
        control={form.control}
        name="phone"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            keyboardType="phone-pad"
            label="Phone number"
            maxLength={10}
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="9876543210"
            textContentType="telephoneNumber"
            value={field.value}
          />
        )}
      />
      <Controller
        control={form.control}
        name="gender"
        render={({ field, fieldState }) => (
          <View style={styles.fieldWrap}>
            <Text style={styles.fieldLabel}>Gender</Text>
            <View style={styles.chipRow}>
              {(["male", "female", "other"] as const).map((g) => (
                <Pressable
                  key={g}
                  accessibilityRole="button"
                  style={[styles.chip, field.value === g && styles.chipActive]}
                  onPress={() => field.onChange(g)}
                >
                  <Text style={[styles.chipText, field.value === g && styles.chipTextActive]}>
                    {g.charAt(0).toUpperCase() + g.slice(1)}
                  </Text>
                </Pressable>
              ))}
            </View>
            {fieldState.error ? <Text style={styles.errorText}>{fieldState.error.message}</Text> : null}
          </View>
        )}
      />
      <Controller
        control={form.control}
        name="dob"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            keyboardType="number-pad"
            label="Date of birth"
            maxLength={10}
            onBlur={field.onBlur}
            onChangeText={(text) => {
              let cleaned = text.replace(/\D/g, "");
              if (cleaned.length > 2 && cleaned.length <= 4) {
                cleaned = `${cleaned.slice(0, 2)}/${cleaned.slice(2)}`;
              } else if (cleaned.length > 4) {
                cleaned = `${cleaned.slice(0, 2)}/${cleaned.slice(2, 4)}/${cleaned.slice(4, 8)}`;
              }
              field.onChange(cleaned);
            }}
            placeholder="DD/MM/YYYY"
            value={field.value}
          />
        )}
      />
    </SetupScaffold>
  );
}

const styles = StyleSheet.create({
  fieldWrap: {
    gap: 8,
  },
  fieldLabel: {
    color: "#09090A",
    fontSize: 14,
    fontWeight: "700",
  },
  chipRow: {
    flexDirection: "row",
    gap: 10,
  },
  chip: {
    flex: 1,
    height: 48,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.1)",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#FFFFFF",
  },
  chipActive: {
    backgroundColor: "#0A0A0B",
    borderColor: "#0A0A0B",
  },
  chipText: {
    color: "#666666",
    fontSize: 15,
    fontWeight: "700",
  },
  chipTextActive: {
    color: "#FFFFFF",
  },
  errorText: {
    color: "#B42318",
    fontSize: 13,
    fontWeight: "600",
  },
});
