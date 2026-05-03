import { Ionicons } from "@expo/vector-icons";
import type * as ImagePicker from "expo-image-picker";
import { StatusBar } from "expo-status-bar";
import type { PropsWithChildren } from "react";
import {
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { KeyboardAvoidingView } from "react-native-keyboard-controller";
import Animated, { FadeInDown } from "react-native-reanimated";
import { SafeAreaView } from "react-native-safe-area-context";

import { Button } from "@/components/ui/Button";
import { ProfileAvatar } from "@/features/userSetup/components/ProfileAvatar";

interface SetupScaffoldProps extends PropsWithChildren {
  title: string;
  eyebrow?: string;
  description?: string;
  copyAlign?: "center" | "start";
  contentPaddingBottom?: number;
  contentPaddingTop?: number;
  progress?: number;
  primaryLabel?: string;
  primaryLoading?: boolean;
  primaryDisabled?: boolean;
  onPrimaryPress?: () => void;
  onBack?: () => void;
  error?: string | null;
  showAvatar?: boolean;
  avatarError?: string | null;
  avatarPreviewUri?: string | null;
  avatarUrl?: string | null;
  isAvatarUploading?: boolean;
  onAvatarError?: (message: string) => void;
  onAvatarPicked?: (asset: ImagePicker.ImagePickerAsset) => void | Promise<void>;
  showIntro?: boolean;
}

export function SetupScaffold({
  children,
  copyAlign = "center",
  description,
  error,
  avatarError,
  avatarPreviewUri,
  avatarUrl,
  contentPaddingBottom,
  contentPaddingTop,
  eyebrow = "Urban Parking",
  isAvatarUploading,
  onBack,
  onAvatarError,
  onAvatarPicked,
  onPrimaryPress,
  primaryDisabled,
  primaryLabel,
  primaryLoading,
  progress,
  showAvatar = true,
  showIntro = true,
  title,
}: SetupScaffoldProps) {
  return (
    <SafeAreaView style={styles.screen}>
      <StatusBar backgroundColor="#FFFFFF" style="dark" translucent={false} />
      <View style={styles.topContainer}>
        <View style={styles.header}>
          {onBack ? (
            <Pressable
              accessibilityRole="button"
              hitSlop={10}
              style={styles.backButton}
              onPress={onBack}
            >
              <Ionicons color="#0A0A0B" name="chevron-back" size={22} />
            </Pressable>
          ) : (
            <View style={styles.backButtonPlaceholder} />
          )}
          <Text style={styles.brand}>{eyebrow}</Text>
          <View style={styles.backButtonPlaceholder} />
        </View>
        {typeof progress === "number" ? (
          <View style={styles.progressTrack}>
            <View
              style={[
                styles.progressFill,
                { width: `${Math.max(8, Math.min(100, progress * 100))}%` },
              ]}
            />
          </View>
        ) : null}
      </View>
      <KeyboardAvoidingView
        behavior="padding"
        keyboardVerticalOffset={Platform.OS === "ios" ? 8 : 0}
        style={styles.keyboard}
      >
        <ScrollView
          style={styles.scroll}
          contentContainerStyle={[
            styles.content,
            primaryLabel ? styles.contentWithFooter : null,
            typeof contentPaddingTop === "number" ? { paddingTop: contentPaddingTop } : null,
            typeof contentPaddingBottom === "number" ? { paddingBottom: contentPaddingBottom } : null,
          ]}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          {showIntro ? (
            <Animated.View
              entering={FadeInDown.delay(100).duration(500)}
              style={[styles.copy, copyAlign === "start" ? styles.copyStart : null]}
            >
              {showAvatar ? (
                <ProfileAvatar
                  avatarUrl={avatarUrl}
                  error={avatarError}
                  isUploading={isAvatarUploading}
                  previewUri={avatarPreviewUri}
                  onImagePicked={onAvatarPicked}
                  onPickError={onAvatarError}
                />
              ) : null}
              <Text style={[styles.title, copyAlign === "start" ? styles.titleStart : null]}>{title}</Text>
              {description ? (
                <Text style={[styles.description, copyAlign === "start" ? styles.descriptionStart : null]}>
                  {description}
                </Text>
              ) : null}
            </Animated.View>
          ) : null}
          <Animated.View entering={FadeInDown.delay(200).duration(500)} style={styles.body}>
            {children}
          </Animated.View>
          {error ? <Text style={styles.error}>{error}</Text> : null}
        </ScrollView>
        {primaryLabel && onPrimaryPress ? (
          <View style={styles.footer}>
            <Button
              disabled={primaryDisabled}
              label={primaryLabel}
              loading={primaryLoading}
              style={styles.primaryButton}
              onPress={onPrimaryPress}
            />
          </View>
        ) : null}
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: "#FFFFFF",
  },
  keyboard: {
    flex: 1,
  },
  scroll: {
    flex: 1,
  },
  topContainer: {
    backgroundColor: "#FFFFFF",
    zIndex: 10,
    paddingBottom: 4,
  },
  header: {
    minHeight: 58,
    paddingHorizontal: 18,
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
  },
  backButton: {
    width: 40,
    height: 40,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 20,
    backgroundColor: "#FFFFFF",
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.08)",
  },
  backButtonPlaceholder: {
    width: 40,
    height: 40,
  },
  brand: {
    color: "#0A0A0B",
    fontSize: 15,
    fontWeight: "900",
  },
  progressTrack: {
    height: 4,
    marginHorizontal: 20,
    borderRadius: 999,
    backgroundColor: "#E7E7E7",
    overflow: "hidden",
  },
  progressFill: {
    height: 4,
    borderRadius: 999,
    backgroundColor: "#0A0A0B",
  },
  content: {
    flexGrow: 1,
    paddingHorizontal: 20,
    paddingTop: 40,
    paddingBottom: 28,
    gap: 26,
  },
  contentWithFooter: {
    paddingBottom: 112,
  },
  copy: {
    gap: 16,
    alignItems: "center",
  },
  copyStart: {
    alignItems: "flex-start",
  },
  title: {
    color: "#09090A",
    fontSize: 34,
    fontWeight: "900",
    lineHeight: 38,
    textAlign: "center",
  },
  titleStart: {
    textAlign: "left",
  },
  description: {
    color: "#666666",
    fontSize: 15,
    fontWeight: "700",
    lineHeight: 22,
    textAlign: "center",
  },
  descriptionStart: {
    textAlign: "left",
  },
  body: {
    gap: 16,
  },
  error: {
    color: "#B42318",
    fontSize: 14,
    fontWeight: "800",
    lineHeight: 20,
  },
  footer: {
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 24,
    borderTopWidth: 1,
    borderTopColor: "#EFEFEF",
    backgroundColor: "#FFFFFF",
  },
  primaryButton: {
    height: 60,
    borderRadius: 30,
  },
});
