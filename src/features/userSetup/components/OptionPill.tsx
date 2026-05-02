import { Pressable, StyleSheet, Text } from "react-native";

interface OptionPillProps<T extends string> {
  label: string;
  value: T;
  selectedValue: T;
  onSelect: (value: T) => void;
}

export function OptionPill<T extends string>({ label, onSelect, selectedValue, value }: OptionPillProps<T>) {
  const selected = selectedValue === value;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      style={[styles.pill, selected && styles.selected]}
      onPress={() => onSelect(value)}
    >
      <Text style={[styles.label, selected && styles.selectedLabel]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  pill: {
    minHeight: 48,
    paddingHorizontal: 16,
    borderRadius: 24,
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.12)",
    backgroundColor: "#FFFFFF",
    alignItems: "center",
    justifyContent: "center"
  },
  selected: {
    backgroundColor: "#0A0A0B",
    borderColor: "#0A0A0B"
  },
  label: {
    color: "#0A0A0B",
    fontSize: 14,
    fontWeight: "900"
  },
  selectedLabel: {
    color: "#FFFFFF"
  }
});
