export const LISTING_TIME_ZONE = "Asia/Kolkata";
export const TIME_SLOT_INTERVAL_MINUTES = 30;

export const weekDays = [
  { label: "Sun", value: 0 },
  { label: "Mon", value: 1 },
  { label: "Tue", value: 2 },
  { label: "Wed", value: 3 },
  { label: "Thu", value: 4 },
  { label: "Fri", value: 5 },
  { label: "Sat", value: 6 }
] as const;

const monthLabels = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

export interface AvailabilityRuleInput {
  weekday: number;
  startMinute: number;
  endMinute: number;
}

export const defaultAvailabilityRules: AvailabilityRuleInput[] = [1, 2, 3, 4, 5].map((weekday) => ({
  weekday,
  startMinute: 8 * 60,
  endMinute: 21 * 60
}));

export const timeSlotOptions = Array.from({ length: (24 * 60) / TIME_SLOT_INTERVAL_MINUTES }, (_, index) => {
  const minutes = index * TIME_SLOT_INTERVAL_MINUTES;

  return {
    label: formatMinutesAsTime(minutes),
    value: String(minutes)
  };
});

export function formatMinutesAsTime(minutes: number) {
  const normalizedMinutes = Math.max(0, Math.min(24 * 60 - TIME_SLOT_INTERVAL_MINUTES, minutes));
  const hour24 = Math.floor(normalizedMinutes / 60);
  const minute = normalizedMinutes % 60;
  const period = hour24 >= 12 ? "PM" : "AM";
  const hour12 = hour24 % 12 || 12;

  return `${hour12}:${String(minute).padStart(2, "0")} ${period}`;
}

export function getTodayDateKeyInIndia(date = new Date()) {
  const parts = new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "2-digit",
    timeZone: LISTING_TIME_ZONE,
    year: "numeric"
  }).formatToParts(date);
  const partValue = (type: string) => parts.find((part) => part.type === type)?.value ?? "";

  return `${partValue("year")}-${partValue("month")}-${partValue("day")}`;
}

export function toDateKey(year: number, monthIndex: number, day: number) {
  return `${year}-${String(monthIndex + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

export function formatDateKey(dateKey: string) {
  const [year, month, day] = dateKey.split("-").map(Number);

  if (!year || !month || !day) {
    return dateKey;
  }

  return `${day} ${monthLabels[month - 1]}`;
}

export function formatAvailabilityRule(rule: AvailabilityRuleInput) {
  const weekday = weekDays.find((day) => day.value === rule.weekday)?.label ?? "Day";

  return `${weekday}, ${formatMinutesAsTime(rule.startMinute)} - ${formatMinutesAsTime(rule.endMinute)}`;
}

export function formatAvailabilitySummary(rules: AvailabilityRuleInput[], blockedDates: string[]) {
  if (rules.length === 0) {
    return "";
  }

  const sortedRules = [...rules].sort((left, right) => {
    if (left.startMinute !== right.startMinute) {
      return left.startMinute - right.startMinute;
    }

    if (left.endMinute !== right.endMinute) {
      return left.endMinute - right.endMinute;
    }

    return left.weekday - right.weekday;
  });
  const groups = new Map<string, number[]>();

  sortedRules.forEach((rule) => {
    const key = `${rule.startMinute}-${rule.endMinute}`;
    groups.set(key, [...(groups.get(key) ?? []), rule.weekday]);
  });

  const ruleSummary = Array.from(groups.entries())
    .map(([key, weekdays]) => {
      const [startMinute = 0, endMinute = 0] = key.split("-").map(Number);

      return `${formatWeekdayRange(weekdays)} ${formatMinutesAsTime(startMinute)} - ${formatMinutesAsTime(endMinute)}`;
    })
    .join("; ");
  const blockedSummary =
    blockedDates.length > 0 ? ` Blocked: ${blockedDates.slice(0, 4).map(formatDateKey).join(", ")}${blockedDates.length > 4 ? "..." : ""}` : "";

  return `${ruleSummary}.${blockedSummary}`.trim();
}

function formatWeekdayRange(weekdays: number[]) {
  const sortedWeekdays = [...new Set(weekdays)].sort((left, right) => left - right);
  const isConsecutive = sortedWeekdays.every((weekday, index) => {
    const previousWeekday = sortedWeekdays[index - 1];

    return index === 0 || (typeof previousWeekday === "number" && weekday === previousWeekday + 1);
  });

  if (sortedWeekdays.length > 1 && isConsecutive) {
    const firstWeekday = sortedWeekdays[0] ?? 0;
    const lastWeekday = sortedWeekdays[sortedWeekdays.length - 1] ?? firstWeekday;
    const first = weekDays.find((day) => day.value === firstWeekday)?.label ?? "";
    const last = weekDays.find((day) => day.value === lastWeekday)?.label ?? "";

    return `${first}-${last}`;
  }

  return sortedWeekdays.map((weekday) => weekDays.find((day) => day.value === weekday)?.label ?? "").join(", ");
}
