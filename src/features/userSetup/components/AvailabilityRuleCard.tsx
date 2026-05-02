import { Ionicons } from "@expo/vector-icons";
import { Pressable, StyleSheet, Text, View } from "react-native";

import type { AvailabilityRuleInput } from "@/features/userSetup/utils/availability";
import { formatAvailabilityRule } from "@/features/userSetup/utils/availability";

interface AvailabilityRuleCardProps {
  rule: AvailabilityRuleInput;
  onDelete: () => void;
}

export function AvailabilityRuleCard({ onDelete, rule }: AvailabilityRuleCardProps) {
  return (
    <View style={styles.card}>
      <Text style={styles.text}>{formatAvailabilityRule(rule)}</Text>
      <Pressable accessibilityLabel="Remove availability rule" accessibilityRole="button" hitSlop={8} onPress={onDelete}>
        <Ionicons color="#0A0A0B" name="trash-outline" size={18} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    minHeight: 48,
    paddingHorizontal: 14,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "#E3E3E3",
    backgroundColor: "#FFFFFF",
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 12
  },
  text: {
    flex: 1,
    color: "#0A0A0B",
    fontSize: 14,
    fontWeight: "900",
    lineHeight: 19
  }
});
