import { Ionicons } from "@expo/vector-icons";
import { type ComponentProps } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { useAppTheme } from "@/theme/useAppTheme";

type IconName = ComponentProps<typeof Ionicons>["name"];

interface TopNavBarProps {
  onRightPress?: () => void;
  rightIcon?: IconName;
  title: string;
}

export function TopNavBar({
  onRightPress,
  rightIcon = "notifications-outline",
  title,
}: TopNavBarProps) {
  const { colors } = useAppTheme();

  return (
    <View
      style={[
        styles.container,
        {
          backgroundColor: colors.surface,
        },
      ]}
    >
      <View style={styles.brandRow}>
        <Text numberOfLines={1} style={[styles.title, { color: colors.text }]}>
          {title}
        </Text>
        <Ionicons color="#E53935" name="heart" size={18} style={styles.titleHeart} />
      </View>

      <Pressable
        accessibilityLabel="Notifications"
        accessibilityRole="button"
        hitSlop={10}
        style={[styles.iconButton, { borderColor: colors.border, backgroundColor: colors.surface }]}
        onPress={onRightPress}
      >
        <Ionicons color={colors.text} name={rightIcon} size={20} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    minHeight: 68,
    borderBottomWidth: 0,
    paddingHorizontal: 20,
    paddingVertical: 14,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
  },
  brandRow: {
    flex: 1,
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingRight: 12,
  },
  title: {
    flexShrink: 1,
    fontSize: 18,
    lineHeight: 22,
    fontWeight: "900",
  },
  titleHeart: {
    flexShrink: 0,
  },
  iconButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
    backgroundColor: "transparent",
  },
});
