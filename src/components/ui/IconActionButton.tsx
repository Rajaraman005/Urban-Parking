import { Ionicons } from "@expo/vector-icons";
import { memo, type ComponentProps } from "react";
import { Pressable, StyleSheet, Text } from "react-native";

import { useAppTheme } from "@/theme/useAppTheme";

export type IconActionButtonIcon = ComponentProps<typeof Ionicons>["name"];

export interface IconActionButtonProps {
  accessibilityLabel: string;
  icon: IconActionButtonIcon;
  label: string;
  onPress: () => void;
  width?: number;
}

export const IconActionButton = memo(function IconActionButton({
  accessibilityLabel,
  icon,
  label,
  onPress,
  width,
}: IconActionButtonProps) {
  const { colors } = useAppTheme();

  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      android_ripple={{ color: "rgba(255,255,255,0.12)", borderless: false }}
      style={({ pressed }) => [
        styles.button,
        { backgroundColor: colors.primary, width },
        pressed ? styles.pressed : null,
      ]}
      onPress={onPress}
    >
      <Ionicons color={colors.primaryText} name={icon} size={23} />
      <Text numberOfLines={1} style={[styles.label, { color: colors.primaryText }]}>
        {label}
      </Text>
    </Pressable>
  );
});

const styles = StyleSheet.create({
  button: {
    height: 76,
    minWidth: 82,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 11,
    gap: 7,
    shadowColor: "#0A0A0B",
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.12,
    shadowRadius: 14,
    elevation: 5,
  },
  pressed: {
    opacity: 0.82,
    transform: [{ scale: 0.98 }],
  },
  label: {
    fontSize: 12,
    fontWeight: "900",
    lineHeight: 15,
    textAlign: "center",
  },
});
