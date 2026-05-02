import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { AvailabilityRuleCard } from "@/features/userSetup/components/AvailabilityRuleCard";
import { TimeSlotSelect } from "@/features/userSetup/components/TimeSlotSelect";
import type { AvailabilityRuleInput } from "@/features/userSetup/utils/availability";
import { weekDays } from "@/features/userSetup/utils/availability";

interface WeeklyAvailabilityEditorProps {
  error?: string;
  rules: AvailabilityRuleInput[];
  onChange: (rules: AvailabilityRuleInput[]) => void;
}

export function WeeklyAvailabilityEditor({ error, onChange, rules }: WeeklyAvailabilityEditorProps) {
  const [selectedWeekdays, setSelectedWeekdays] = useState<number[]>([1, 2, 3, 4, 5]);
  const [startMinute, setStartMinute] = useState(8 * 60);
  const [endMinute, setEndMinute] = useState(21 * 60);
  const [localError, setLocalError] = useState<string | null>(null);
  const sortedRules = useMemo(() => [...rules].sort((left, right) => left.weekday - right.weekday), [rules]);

  const toggleWeekday = (weekday: number) => {
    setSelectedWeekdays((current) =>
      current.includes(weekday) ? current.filter((item) => item !== weekday) : [...current, weekday].sort((left, right) => left - right)
    );
  };

  const applyToSelectedDays = () => {
    if (selectedWeekdays.length === 0) {
      setLocalError("Select at least one day.");
      return;
    }

    if (endMinute <= startMinute) {
      setLocalError("End time must be after start time.");
      return;
    }

    setLocalError(null);
    const nextRules = [
      ...rules.filter((rule) => !selectedWeekdays.includes(rule.weekday)),
      ...selectedWeekdays.map((weekday) => ({ weekday, startMinute, endMinute }))
    ].sort((left, right) => left.weekday - right.weekday);

    onChange(nextRules);
  };

  const deleteRule = (weekday: number) => {
    onChange(rules.filter((rule) => rule.weekday !== weekday));
  };

  return (
    <View style={styles.wrapper}>
      <View style={styles.header}>
        <Text style={styles.title}>Weekly availability</Text>
        <Text style={styles.subtitle}>Choose days and timings renters can book.</Text>
      </View>
      <View style={styles.weekdays}>
        {weekDays.map((day) => {
          const selected = selectedWeekdays.includes(day.value);

          return (
            <Pressable
              key={day.value}
              accessibilityRole="button"
              accessibilityState={{ selected }}
              style={[styles.dayChip, selected ? styles.dayChipSelected : null]}
              onPress={() => toggleWeekday(day.value)}
            >
              <Text style={[styles.dayText, selected ? styles.dayTextSelected : null]}>{day.label}</Text>
            </Pressable>
          );
        })}
      </View>
      <View style={styles.timeRow}>
        <View style={styles.timeControl}>
          <TimeSlotSelect label="From" value={startMinute} onChange={setStartMinute} />
        </View>
        <View style={styles.timeControl}>
          <TimeSlotSelect label="To" value={endMinute} onChange={setEndMinute} />
        </View>
      </View>
      <Button label="Apply to selected days" style={styles.applyButton} onPress={applyToSelectedDays} />
      {localError || error ? <Text style={styles.error}>{localError ?? error}</Text> : null}
      <View style={styles.rules}>
        {sortedRules.map((rule) => (
          <AvailabilityRuleCard key={rule.weekday} rule={rule} onDelete={() => deleteRule(rule.weekday)} />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    gap: 14
  },
  header: {
    gap: 4
  },
  title: {
    color: "#0A0A0B",
    fontSize: 17,
    fontWeight: "900"
  },
  subtitle: {
    color: "#666666",
    fontSize: 13,
    fontWeight: "700",
    lineHeight: 18
  },
  weekdays: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8
  },
  dayChip: {
    width: 44,
    height: 44,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: "#E3E3E3",
    backgroundColor: "#FFFFFF",
    alignItems: "center",
    justifyContent: "center"
  },
  dayChipSelected: {
    borderColor: "#0A0A0B",
    backgroundColor: "#0A0A0B"
  },
  dayText: {
    color: "#0A0A0B",
    fontSize: 13,
    fontWeight: "900"
  },
  dayTextSelected: {
    color: "#FFFFFF"
  },
  timeRow: {
    flexDirection: "row",
    gap: 12,
    alignItems: "flex-start"
  },
  timeControl: {
    flex: 1
  },
  applyButton: {
    minHeight: 52,
    borderRadius: 26
  },
  error: {
    color: "#B42318",
    fontSize: 13,
    fontWeight: "800",
    lineHeight: 18
  },
  rules: {
    gap: 8
  }
});
