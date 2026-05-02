import { Ionicons } from "@expo/vector-icons";
import * as ImagePicker from "expo-image-picker";
import { useCallback, useState } from "react";
import {
  ActivityIndicator,
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";
import Animated, { FadeIn } from "react-native-reanimated";

import { useAuthStore } from "@/features/auth/store/authStore";

function getInitials(fullName: string | null | undefined, email: string | null | undefined): string {
  if (fullName && fullName.trim().length > 0) {
    const parts = fullName.trim().split(/\s+/);

    if (parts.length >= 2 && parts[0] && parts[1]) {
      return ((parts[0][0] ?? "") + (parts[1][0] ?? "")).toUpperCase();
    }

    return fullName.trim().substring(0, 2).toUpperCase();
  }

  if (email) {
    const local = email.split("@")[0] ?? "";

    return local.substring(0, 2).toUpperCase();
  }

  return "UP";
}

function getGradientPair(initials: string): [string, string] {
  const palettes: [string, string][] = [
    ["#6366F1", "#818CF8"],
    ["#8B5CF6", "#A78BFA"],
    ["#EC4899", "#F472B6"],
    ["#14B8A6", "#2DD4BF"],
    ["#F59E0B", "#FBBF24"],
    ["#06B6D4", "#22D3EE"],
    ["#10B981", "#34D399"],
    ["#F97316", "#FB923C"],
  ];
  let hash = 0;

  for (let i = 0; i < initials.length; i++) {
    hash = initials.charCodeAt(i) + ((hash << 5) - hash);
  }

  return palettes[Math.abs(hash) % palettes.length] ?? ["#F97316", "#FB923C"];
}

interface ProfileAvatarProps {
  avatarUrl?: string | null;
  error?: string | null;
  isUploading?: boolean;
  onImagePicked?: (asset: ImagePicker.ImagePickerAsset) => void | Promise<void>;
  onPickError?: (message: string) => void;
  previewUri?: string | null;
  size?: number;
}

export function ProfileAvatar({
  avatarUrl: avatarUrlOverride,
  error,
  isUploading = false,
  onImagePicked,
  onPickError,
  previewUri,
  size = 80,
}: ProfileAvatarProps) {
  const profile = useAuthStore((s) => s.profile);
  const user = useAuthStore((s) => s.user);

  const avatarUrl = avatarUrlOverride ?? profile?.avatar_url ?? null;
  const fullName = profile?.full_name ?? null;
  const email = user?.email ?? null;
  const initials = getInitials(fullName, email);
  const [bgStart] = getGradientPair(initials);
  const [isPicking, setIsPicking] = useState(false);

  const isBusy = isPicking || isUploading;
  const displayUri = previewUri ?? avatarUrl;

  const pickImage = useCallback(async () => {
    if (isBusy) {
      return;
    }

    setIsPicking(true);

    try {
      const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();

      if (!permission.granted) {
        onPickError?.("Allow photo access to upload a profile photo.");
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        allowsEditing: true,
        aspect: [1, 1],
        mediaTypes: ["images"],
        quality: 0.8,
      });

      if (!result.canceled && result.assets[0]) {
        await onImagePicked?.(result.assets[0]);
      }
    } catch {
      onPickError?.("Profile photo picker could not be opened.");
    } finally {
      setIsPicking(false);
    }
  }, [isBusy, onImagePicked, onPickError]);

  const badgeSize = Math.round(size * 0.32);
  const borderW = Math.round(size * 0.04);

  return (
    <Animated.View entering={FadeIn.duration(500)} style={styles.wrapper}>
      <Pressable
        accessibilityLabel="Upload profile photo"
        accessibilityRole="button"
        disabled={isBusy}
        style={({ pressed }) => [styles.pressable, (pressed || isBusy) && styles.pressableMuted]}
        onPress={pickImage}
      >
        <View
          style={[
            styles.ring,
            {
              borderColor: "rgba(10,10,10,0.06)",
              borderRadius: (size + borderW * 2) / 2,
              borderWidth: borderW,
              height: size + borderW * 2,
              width: size + borderW * 2,
            },
          ]}
        >
          {displayUri ? (
            <Image
              source={{ uri: displayUri }}
              style={[
                styles.image,
                {
                  borderRadius: size / 2,
                  height: size,
                  width: size,
                },
              ]}
            />
          ) : (
            <View
              style={[
                styles.initialsCircle,
                {
                  backgroundColor: bgStart,
                  borderRadius: size / 2,
                  height: size,
                  width: size,
                },
              ]}
            >
              <Text style={[styles.initialsText, { fontSize: Math.round(size * 0.34) }]}>
                {initials}
              </Text>
            </View>
          )}
          {isUploading ? <View style={styles.uploadScrim} /> : null}
        </View>

        <Animated.View
          entering={FadeIn.delay(400).duration(300)}
          style={[
            styles.badge,
            {
              borderRadius: badgeSize / 2,
              bottom: 0,
              height: badgeSize,
              right: 0,
              width: badgeSize,
            },
          ]}
        >
          {isBusy ? (
            <ActivityIndicator color="#FFFFFF" size={Math.round(badgeSize * 0.5)} />
          ) : (
            <Ionicons color="#FFFFFF" name="camera" size={Math.round(badgeSize * 0.5)} />
          )}
        </Animated.View>
      </Pressable>
      {error ? <Text style={styles.error}>{error}</Text> : null}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    alignItems: "center",
    alignSelf: "center",
    gap: 8,
  },
  pressable: {
    opacity: 1,
  },
  pressableMuted: {
    opacity: 0.86,
  },
  ring: {
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
  },
  image: {
    resizeMode: "cover",
  },
  initialsCircle: {
    alignItems: "center",
    justifyContent: "center",
  },
  initialsText: {
    color: "#FFFFFF",
    fontWeight: "800",
    letterSpacing: 1,
  },
  badge: {
    alignItems: "center",
    backgroundColor: "#0A0A0B",
    borderColor: "#FFFFFF",
    borderWidth: 2.5,
    justifyContent: "center",
    position: "absolute",
  },
  uploadScrim: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(0,0,0,0.18)",
  },
  error: {
    color: "#B42318",
    fontSize: 12,
    fontWeight: "700",
    lineHeight: 16,
    maxWidth: 220,
    textAlign: "center",
  },
});
