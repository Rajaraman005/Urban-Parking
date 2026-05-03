import { Ionicons } from "@expo/vector-icons";
import { memo, type ComponentProps } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { useAppTheme } from "@/theme/useAppTheme";

// ─── Types ─────────────────────────────────────────────────────────────────────

export type IconActionButtonIcon = ComponentProps<typeof Ionicons>["name"];

export interface HomeDiscoveryAction {
  accessibilityLabel: string;
  icon: IconActionButtonIcon;
  id: string;
  label: string;
  onPress: () => void;
}

interface HomeDiscoveryActionsProps {
  actions: readonly HomeDiscoveryAction[];
  subtitle?: string;
  title?: string;
}

// ─── Main Section ──────────────────────────────────────────────────────────────

export const HomeDiscoveryActions = memo(function HomeDiscoveryActions({
  actions,
  subtitle = "Choose how you want to discover nearby options.",
  title = "What do you need today?",
}: HomeDiscoveryActionsProps) {
  const { colors } = useAppTheme();

  return (
    <View style={styles.container}>
      <View style={styles.copyBlock}>
        <Text style={[styles.title, { color: colors.text }]}>{title}</Text>
        <Text style={[styles.subtitle, { color: colors.muted }]}>{subtitle}</Text>
      </View>

      {/* Button row — uses flex so buttons fill evenly, no overflow */}
      <View style={styles.buttonRow}>
        {actions.map((action, index) => (
          <FilterButton
            key={action.id}
            accessibilityLabel={action.accessibilityLabel}
            icon={action.icon}
            label={action.label}
            onPress={action.onPress}
            isLast={index === actions.length - 1}
          />
        ))}
      </View>
    </View>
  );
});

// ─── Filter Button ─────────────────────────────────────────────────────────────

interface FilterButtonProps {
  accessibilityLabel: string;
  icon: IconActionButtonIcon;
  label: string;
  onPress: () => void;
  isLast?: boolean;
}

const FilterButton = memo(function FilterButton({
  accessibilityLabel,
  icon,
  label,
  onPress,
  isLast = false,
}: FilterButtonProps) {
  const { colors } = useAppTheme();

  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      android_ripple={{ color: "rgba(255,255,255,0.12)", borderless: false }}
      style={({ pressed }) => [
        styles.filterBtn,
        { backgroundColor: colors.primary },
        !isLast ? styles.filterBtnGap : null,
        pressed ? styles.pressed : null,
      ]}
      onPress={onPress}
    >
      <Ionicons color={colors.primaryText} name={icon} size={22} />
      <Text numberOfLines={1} style={[styles.filterLabel, { color: colors.primaryText }]}>
        {label}
      </Text>
    </Pressable>
  );
});

// ─── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 20,
    paddingTop: 20,
    gap: 14,
  },
  copyBlock: {
    gap: 6,
  },
  title: {
    fontSize: 22,
    fontWeight: "900",
    lineHeight: 27,
  },
  subtitle: {
    fontSize: 13,
    fontWeight: "600",
    lineHeight: 18,
  },

  // ─ Button row ───────────────────────────────────────────────────────────────
  buttonRow: {
    flexDirection: "row",
    width: "100%",
  },
  filterBtn: {
    flex: 1,
    height: 76,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 14,
    paddingVertical: 11,
    gap: 7,
    // Premium shadow
    shadowColor: "#0A0A0B",
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.12,
    shadowRadius: 10,
    elevation: 4,
  },
  filterBtnGap: {
    marginRight: 10,
  },
  pressed: {
    opacity: 0.82,
    transform: [{ scale: 0.97 }],
  },
  filterLabel: {
    fontSize: 12,
    fontWeight: "800",
    lineHeight: 15,
    textAlign: "center",
  },
});
