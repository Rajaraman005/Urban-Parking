import { Ionicons } from "@expo/vector-icons";
import { useMemo, useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

export interface SelectOption<T extends string> {
  label: string;
  value: T;
}

interface SelectFieldProps<T extends string> {
  error?: string;
  label: string;
  menuMaxHeight?: number;
  open?: boolean;
  options: SelectOption<T>[];
  placeholder?: string;
  value: T;
  onChange: (value: T) => void;
  onOpenChange?: (open: boolean) => void;
}

export function SelectField<T extends string>({
  error,
  label,
  menuMaxHeight,
  onOpenChange,
  onChange,
  open,
  options,
  placeholder = "Select",
  value
}: SelectFieldProps<T>) {
  const [localOpen, setLocalOpen] = useState(false);
  const isOpen = open ?? localOpen;
  const selectedOption = useMemo(() => options.find((option) => option.value === value), [options, value]);

  const setOpen = (nextOpen: boolean) => {
    setLocalOpen(nextOpen);
    onOpenChange?.(nextOpen);
  };

  const chooseOption = (nextValue: T) => {
    onChange(nextValue);
    setOpen(false);
  };

  return (
    <View style={styles.wrapper}>
      <Text style={styles.label}>{label}</Text>
      <Pressable
        accessibilityRole="button"
        accessibilityState={{ expanded: isOpen }}
        style={[styles.trigger, isOpen ? styles.triggerOpen : null, error ? styles.triggerError : null]}
        onPress={() => setOpen(!isOpen)}
      >
        <Text style={[styles.triggerText, selectedOption ? null : styles.placeholder]}>
          {selectedOption?.label ?? placeholder}
        </Text>
        <Ionicons color="#0A0A0B" name={isOpen ? "chevron-up" : "chevron-down"} size={20} />
      </Pressable>
      {isOpen ? (
        <View style={styles.menu}>
          <ScrollView nestedScrollEnabled showsVerticalScrollIndicator={false} style={menuMaxHeight ? { maxHeight: menuMaxHeight } : undefined}>
            {options.map((option) => {
              const selected = option.value === value;

              return (
                <Pressable
                  key={option.value}
                  accessibilityRole="button"
                  accessibilityState={{ selected }}
                  style={[styles.option, selected ? styles.optionSelected : null]}
                  onPress={() => chooseOption(option.value)}
                >
                  <Text style={[styles.optionText, selected ? styles.optionTextSelected : null]}>{option.label}</Text>
                  {selected ? <Ionicons color="#FFFFFF" name="checkmark" size={18} /> : null}
                </Pressable>
              );
            })}
          </ScrollView>
        </View>
      ) : null}
      {error ? <Text style={styles.error}>{error}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    gap: 8
  },
  label: {
    color: "#0B0B0C",
    fontSize: 13,
    fontWeight: "700"
  },
  trigger: {
    minHeight: 56,
    paddingHorizontal: 16,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#E3E3E3",
    backgroundColor: "#FFFFFF",
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between"
  },
  triggerOpen: {
    borderColor: "#0A0A0B"
  },
  triggerError: {
    borderColor: "#B42318"
  },
  triggerText: {
    color: "#0A0A0B",
    fontSize: 16,
    fontWeight: "900"
  },
  placeholder: {
    color: "#8A8A8A"
  },
  menu: {
    padding: 6,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "#E3E3E3",
    backgroundColor: "#FFFFFF",
    gap: 4
  },
  option: {
    minHeight: 46,
    paddingHorizontal: 12,
    borderRadius: 9,
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between"
  },
  optionSelected: {
    backgroundColor: "#0A0A0B"
  },
  optionText: {
    color: "#0A0A0B",
    fontSize: 15,
    fontWeight: "900"
  },
  optionTextSelected: {
    color: "#FFFFFF"
  },
  error: {
    color: "#B42318",
    fontSize: 13,
    fontWeight: "700"
  }
});
