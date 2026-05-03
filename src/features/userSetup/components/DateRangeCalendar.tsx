import { Ionicons } from "@expo/vector-icons";
import { useEffect, useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { getTodayDateKeyInIndia, toDateKey } from "@/features/userSetup/utils/availability";

interface DateRangeCalendarProps {
  startDate: string;
  endDate: string;
  skipWeekends?: boolean;
  error?: string;
  onChange: (next: { startDate: string; endDate: string }) => void;
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

export function DateRangeCalendar({ startDate, endDate, skipWeekends = false, error, onChange }: DateRangeCalendarProps) {
  const todayKey = getTodayDateKeyInIndia();
  const today = new Date();
  const [visibleMonth, setVisibleMonth] = useState(new Date(today.getFullYear(), today.getMonth(), 1));
  const cells = useMemo(() => buildCalendarCells(visibleMonth), [visibleMonth]);

  useEffect(() => {
    if (!startDate) {
      return;
    }

    const [year, month] = startDate.split("-").map(Number);

    if (!year || !month) {
      return;
    }

    setVisibleMonth(new Date(year, month - 1, 1));
  }, [startDate]);

  const changeMonth = (offset: number) => {
    setVisibleMonth((current) => new Date(current.getFullYear(), current.getMonth() + offset, 1));
  };

  const selectDate = (dateKey: string) => {
    if (dateKey < todayKey || (skipWeekends && isWeekendDateKey(dateKey))) {
      return;
    }

    if (!startDate || endDate) {
      onChange({ endDate: "", startDate: dateKey });
      return;
    }

    if (dateKey < startDate) {
      onChange({ endDate: "", startDate: dateKey });
      return;
    }

    onChange({ endDate: dateKey, startDate });
  };

  return (
    <View style={styles.wrapper}>
      <View style={styles.header}>
        <Pressable accessibilityLabel="Previous month" accessibilityRole="button" hitSlop={8} style={styles.monthButton} onPress={() => changeMonth(-1)}>
          <Ionicons color="#111111" name="chevron-back" size={20} />
        </Pressable>
        <Text style={styles.monthLabel}>
          {monthLabels[visibleMonth.getMonth()]} {visibleMonth.getFullYear()}
        </Text>
        <Pressable accessibilityLabel="Next month" accessibilityRole="button" hitSlop={8} style={styles.monthButton} onPress={() => changeMonth(1)}>
          <Ionicons color="#111111" name="chevron-forward" size={20} />
        </Pressable>
      </View>
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

          const weekend = isWeekendDateKey(cell.dateKey);
          const disabled = cell.dateKey < todayKey || (skipWeekends && weekend);
          const isStart = startDate === cell.dateKey;
          const isEnd = endDate === cell.dateKey;
          const isRange = Boolean(
            startDate &&
              endDate &&
              cell.dateKey > startDate &&
              cell.dateKey < endDate &&
              !(skipWeekends && weekend)
          );

          return (
            <Pressable
              key={cell.dateKey}
              accessibilityRole="button"
              accessibilityState={{ disabled, selected: isStart || isEnd || isRange }}
              disabled={disabled}
              style={[styles.dayCell, disabled ? styles.dayCellDisabled : null]}
              onPress={() => selectDate(cell.dateKey)}
            >
              <View
                style={[
                  styles.dayBadge,
                  isRange ? styles.dayBadgeInRange : null,
                  isStart || isEnd ? styles.dayBadgeSelected : null
                ]}
              >
                <Text
                  style={[
                  styles.dayText,
                  isStart || isEnd ? styles.dayTextSelected : null,
                  weekend && skipWeekends ? styles.dayTextWeekendDisabled : null,
                  disabled ? styles.dayTextDisabled : null
                ]}
              >
                  {cell.day}
                </Text>
              </View>
            </Pressable>
          );
        })}
      </View>
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

function isWeekendDateKey(dateKey: string) {
  const [year, month, day] = dateKey.split("-").map(Number);

  if (!year || !month || !day) {
    return false;
  }

  const weekDay = new Date(year, month - 1, day).getDay();

  return weekDay === 0 || weekDay === 6;
}

const styles = StyleSheet.create({
  wrapper: {
    gap: 14
  },
  header: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between"
  },
  monthButton: {
    alignItems: "center",
    height: 32,
    justifyContent: "center",
    width: 32
  },
  monthLabel: {
    color: "#111111",
    flex: 1,
    fontSize: 15,
    fontWeight: "900",
    textAlign: "center"
  },
  weekHeader: {
    flexDirection: "row"
  },
  weekdayLabel: {
    color: "#8A8A92",
    flex: 1,
    fontSize: 12,
    fontWeight: "800",
    textAlign: "center"
  },
  grid: {
    flexDirection: "row",
    flexWrap: "wrap",
    rowGap: 8
  },
  dayCell: {
    alignItems: "center",
    justifyContent: "center",
    minHeight: 44,
    width: `${100 / 7}%`
  },
  dayCellDisabled: {
    opacity: 0.28
  },
  dayBadge: {
    alignItems: "center",
    alignSelf: "center",
    aspectRatio: 1,
    borderRadius: 19,
    height: 38,
    justifyContent: "center",
    overflow: "hidden",
    width: 38
  },
  dayBadgeInRange: {
    backgroundColor: "#ECECEF"
  },
  dayBadgeSelected: {
    backgroundColor: "#111111",
    borderRadius: 19
  },
  dayText: {
    color: "#111111",
    fontSize: 14,
    fontWeight: "900"
  },
  dayTextSelected: {
    color: "#FFFFFF"
  },
  dayTextDisabled: {
    color: "#8A8A92"
  },
  dayTextWeekendDisabled: {
    textDecorationLine: "line-through"
  },
  error: {
    color: "#B42318",
    fontSize: 13,
    fontWeight: "800",
    lineHeight: 18
  }
});
