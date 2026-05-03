import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";

import { useAppTheme } from "@/theme/useAppTheme";

interface DiscoveryStateViewProps {
  actionLabel?: string;
  body: string;
  isLoading?: boolean;
  onAction?: () => void;
  title: string;
}

export function DiscoveryStateView({
  actionLabel = "Retry",
  body,
  isLoading = false,
  onAction,
  title
}: DiscoveryStateViewProps) {
  const { colors } = useAppTheme();

  return (
    <View
      accessibilityRole={isLoading ? "progressbar" : "summary"}
      style={[styles.container, { backgroundColor: colors.surface }]}
    >
      {isLoading ? <ActivityIndicator color={colors.primary} /> : null}
      <Text style={[styles.title, { color: colors.text }]}>{title}</Text>
      <Text style={[styles.body, { color: colors.muted }]}>{body}</Text>
      {onAction ? (
        <Pressable
          accessibilityRole="button"
          hitSlop={8}
          onPress={onAction}
          style={[styles.action, { backgroundColor: colors.primary }]}
        >
          <Text style={[styles.actionText, { color: colors.primaryText }]}>{actionLabel}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  action: {
    alignItems: "center",
    borderRadius: 8,
    justifyContent: "center",
    minHeight: 44,
    minWidth: 120,
    paddingHorizontal: 16
  },
  actionText: {
    fontSize: 14,
    fontWeight: "800"
  },
  body: {
    fontSize: 13,
    lineHeight: 18,
    textAlign: "center"
  },
  container: {
    alignItems: "center",
    gap: 10,
    justifyContent: "center",
    minHeight: 180,
    padding: 20
  },
  title: {
    fontSize: 17,
    fontWeight: "900",
    lineHeight: 22,
    textAlign: "center"
  }
});
