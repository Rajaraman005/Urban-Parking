import { Ionicons } from "@expo/vector-icons";
import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { formatDateKey, getTodayDateKeyInIndia, toDateKey } from "@/features/userSetup/utils/availability";

interface BlockedDatesCalendarProps {
  blockedDates: string[];
  error?: string;
  onChange: (blockedDates: string[]) => void;
}

const weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"];
const monthLabels = [
  "January",
  "February",
  "March",
  "April",
  "May",
  "June",
  "July",
  "August",
  "September",
  "October",
  "November",
  "December"
];

export function BlockedDatesCalendar({ blockedDates, error, onChange }: BlockedDatesCalendarProps) {
  const todayKey = getTodayDateKeyInIndia();
  const today = new Date();
  const [visibleMonth, setVisibleMonth] = useState(new Date(today.getFullYear(), today.getMonth(), 1));
  const blockedSet = useMemo(() => new Set(blockedDates), [blockedDates]);
  const cells = useMemo(() => buildCalendarCells(visibleMonth), [visibleMonth]);

  const changeMonth = (offset: number) => {
    setVisibleMonth((current) => new Date(current.getFullYear(), current.getMonth() + offset, 1));
  };

  const toggleDate = (dateKey: string) => {
    if (dateKey < todayKey) {
      return;
    }

    const next = new Set(blockedSet);

    if (next.has(dateKey)) {
      next.delete(dateKey);
    } else {
      next.add(dateKey);
    }

    onChange([...next].sort());
  };

  return (
    <View style={styles.wrapper}>
      <View style={styles.header}>
        <View>
          <Text style={styles.title}>Blocked dates</Text>
          <Text style={styles.subtitle}>Tap dates when your space is not available.</Text>
        </View>
        <View style={styles.monthControls}>
          <Pressable accessibilityLabel="Previous month" accessibilityRole="button" hitSlop={8} onPress={() => changeMonth(-1)}>
            <Ionicons color="#0A0A0B" name="chevron-back" size={20} />
          </Pressable>
          <Pressable accessibilityLabel="Next month" accessibilityRole="button" hitSlop={8} onPress={() => changeMonth(1)}>
            <Ionicons color="#0A0A0B" name="chevron-forward" size={20} />
          </Pressable>
        </View>
      </View>
      <Text style={styles.monthLabel}>
        {monthLabels[visibleMonth.getMonth()]} {visibleMonth.getFullYear()}
      </Text>
      <View style={styles.weekHeader}>
        {weekdayLabels.map((label, index) => (
          <Text key={`${label}-${index}`} style={styles.weekdayLabel}>
            {label}
          </Text>
        ))}
      </View>
      <View style={styles.grid}>
        {cells.map((cell, index) => {
          if (!cell) {
            return <View key={`empty-${index}`} style={styles.dayCell} />;
          }

          const blocked = blockedSet.has(cell.dateKey);
          const disabled = cell.dateKey < todayKey;

          return (
            <Pressable
              key={cell.dateKey}
              accessibilityRole="button"
              accessibilityState={{ disabled, selected: blocked }}
              disabled={disabled}
              style={[styles.dayCell, blocked ? styles.dayBlocked : null, disabled ? styles.dayDisabled : null]}
              onPress={() => toggleDate(cell.dateKey)}
            >
              <Text style={[styles.dayText, blocked ? styles.dayTextBlocked : null, disabled ? styles.dayTextDisabled : null]}>
                {cell.day}
              </Text>
            </Pressable>
          );
        })}
      </View>
      {blockedDates.length > 0 ? <Text style={styles.blockedSummary}>Blocked: {blockedDates.map(formatDateKey).join(", ")}</Text> : null}
      {error ? <Text style={styles.error}>{error}</Text> : null}
    </View>
  );
}

function buildCalendarCells(month: Date) {
  const year = month.getFullYear();
  const monthIndex = month.getMonth();
  const firstDayOffset = new Date(year, monthIndex, 1).getDay();
  const daysInMonth = new Date(year, monthIndex + 1, 0).getDate();
  const cells: ({ dateKey: string; day: number } | null)[] = [];

  for (let index = 0; index < firstDayOffset; index += 1) {
    cells.push(null);
  }

  for (let day = 1; day <= daysInMonth; day += 1) {
    cells.push({ dateKey: toDateKey(year, monthIndex, day), day });
  }

  while (cells.length % 7 !== 0) {
    cells.push(null);
  }

  return cells;
}

const styles = StyleSheet.create({
  wrapper: {
    gap: 14
  },
  header: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 16
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
  monthControls: {
    flexDirection: "row",
    gap: 14
  },
  monthLabel: {
    color: "#0A0A0B",
    fontSize: 15,
    fontWeight: "900",
    textAlign: "center"
  },
  weekHeader: {
    flexDirection: "row"
  },
  weekdayLabel: {
    flex: 1,
    color: "#777777",
    fontSize: 12,
    fontWeight: "900",
    textAlign: "center"
  },
  grid: {
    flexDirection: "row",
    flexWrap: "wrap",
    rowGap: 8
  },
  dayCell: {
    width: `${100 / 7}%`,
    aspectRatio: 1,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 999
  },
  dayBlocked: {
    backgroundColor: "#0A0A0B"
  },
  dayDisabled: {
    opacity: 0.28
  },
  dayText: {
    color: "#0A0A0B",
    fontSize: 14,
    fontWeight: "900"
  },
  dayTextBlocked: {
    color: "#FFFFFF"
  },
  dayTextDisabled: {
    color: "#777777"
  },
  blockedSummary: {
    color: "#666666",
    fontSize: 13,
    fontWeight: "800",
    lineHeight: 18
  },
  error: {
    color: "#B42318",
    fontSize: 13,
    fontWeight: "800",
    lineHeight: 18
  }
});
