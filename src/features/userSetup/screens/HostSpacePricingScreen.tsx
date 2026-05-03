import { Ionicons } from "@expo/vector-icons";
import { zodResolver } from "@hookform/resolvers/zod";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { useEffect, useState } from "react";
import { Controller, useForm } from "react-hook-form";
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

import { SetupScaffold } from "@/features/userSetup/components/SetupScaffold";
import { DateRangeCalendar } from "@/features/userSetup/components/DateRangeCalendar";
import type { RootStackParamList } from "@/core/navigation/types";
import { toAuthError } from "@/features/auth/services/authErrors";
import {
  hostPricingSchema,
  type HostPricingFormInput,
  type HostPricingValues,
} from "@/features/userSetup/schemas/userSetupSchemas";
import { userSetupService } from "@/features/userSetup/services/userSetupService";
import { useUserSetupStore } from "@/features/userSetup/store/userSetupStore";
import type { ParkingSpace } from "@/features/userSetup/types/userSetup.types";
import {
  formatMinutesAsTime,
  timeSlotOptions,
} from "@/features/userSetup/utils/availability";

type Props = NativeStackScreenProps<RootStackParamList, "HostSpacePricing">;

const monthToIndex = {
  Jan: 0,
  Feb: 1,
  Mar: 2,
  Apr: 3,
  May: 4,
  Jun: 5,
  Jul: 6,
  Aug: 7,
  Sep: 8,
  Oct: 9,
  Nov: 10,
  Dec: 11,
} as const;

const defaultValues: HostPricingFormInput = {
  availableFromDate: "",
  availableToDate: "",
  dailyEndMinute: 21 * 60,
  dailyStartMinute: 8 * 60,
  heightFeet: undefined,
  hourlyPrice: 50,
  lengthFeet: 15,
  skipWeekends: false,
  slotsCount: 1,
  widthFeet: 8,
};

const asInputNumber = (value: unknown) =>
  typeof value === "number" || typeof value === "string" ? String(value) : "";

const toDateKey = (year: number, monthIndex: number, day: number) =>
  `${year}-${String(monthIndex + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;

const parseTimeText = (value: string) => {
  const match = value.match(/^(\d{1,2}):(\d{2}) ([AP]M)$/);

  if (!match) {
    return 0;
  }

  const [, hoursText, minutesText, period] = match;
  let hours = Number(hoursText) % 12;

  if (period === "PM") {
    hours += 12;
  }

  return hours * 60 + Number(minutesText);
};

const parseAvailabilitySummary = (summary: string | null) => {
  if (!summary) {
    return null;
  }

  const match = summary.match(
    /^(\d{1,2}) ([A-Z][a-z]{2}) - (\d{1,2}) ([A-Z][a-z]{2}), (All day|\d{1,2}:\d{2} [AP]M - \d{1,2}:\d{2} [AP]M)(?:, Weekdays only)?$/,
  );

  if (!match) {
    return null;
  }

  const [, startDayText, startMonthText, endDayText, endMonthText, hoursText] =
    match;
  const startMonthIndex = monthToIndex[startMonthText as keyof typeof monthToIndex];
  const endMonthIndex = monthToIndex[endMonthText as keyof typeof monthToIndex];

  if (typeof startMonthIndex !== "number" || typeof endMonthIndex !== "number") {
    return null;
  }

  const currentYear = new Date().getFullYear();
  const endYear = endMonthIndex < startMonthIndex ? currentYear + 1 : currentYear;
  const parsed = {
    availableFromDate: toDateKey(currentYear, startMonthIndex, Number(startDayText)),
    availableToDate: toDateKey(endYear, endMonthIndex, Number(endDayText)),
    dailyEndMinute: 21 * 60,
    dailyStartMinute: 8 * 60,
    skipWeekends: summary.includes("Weekdays only"),
  };

  const safeHoursText = hoursText ?? "";

  if (safeHoursText === "All day") {
    return {
      ...parsed,
      dailyEndMinute: 24 * 60,
      dailyStartMinute: 0,
    };
  }

  const [startTimeText, endTimeText] = safeHoursText.split(" - ");

  return {
    ...parsed,
    dailyEndMinute: parseTimeText(endTimeText ?? ""),
    dailyStartMinute: parseTimeText(startTimeText ?? ""),
  };
};

const formatDraftValues = (draft: ParkingSpace): HostPricingFormInput => ({
  availableFromDate:
    draft.available_from_date ??
    parseAvailabilitySummary(draft.availability_summary)?.availableFromDate ??
    "",
  availableToDate:
    draft.available_to_date ??
    parseAvailabilitySummary(draft.availability_summary)?.availableToDate ??
    "",
  dailyEndMinute:
    draft.daily_end_minute ??
    parseAvailabilitySummary(draft.availability_summary)?.dailyEndMinute ??
    21 * 60,
  dailyStartMinute:
    draft.daily_start_minute ??
    parseAvailabilitySummary(draft.availability_summary)?.dailyStartMinute ??
    8 * 60,
  heightFeet: draft.height_feet ?? undefined,
  hourlyPrice: draft.hourly_price ?? 50,
  lengthFeet: draft.length_feet ?? 15,
  skipWeekends:
    draft.skip_weekends ??
    parseAvailabilitySummary(draft.availability_summary)?.skipWeekends ??
    false,
  slotsCount: draft.slots_count ?? 1,
  widthFeet: draft.width_feet ?? 8,
});

export function HostSpacePricingScreen({ navigation, route }: Props) {
  const setDraft = useUserSetupStore((state) => state.setDraft);
  const [draft, setLocalDraft] = useState<ParkingSpace | null>(null);
  const [error, setError] = useState<string | null>(null);
  const form = useForm<HostPricingFormInput, unknown, HostPricingValues>({
    defaultValues,
    mode: "onChange",
    resolver: zodResolver(hostPricingSchema),
  });

  const availableFromDate = form.watch("availableFromDate");
  const availableToDate = form.watch("availableToDate");
  const dailyStartMinute = form.watch("dailyStartMinute");
  const dailyEndMinute = form.watch("dailyEndMinute");
  const isFullDay = dailyStartMinute === 0 && dailyEndMinute === 24 * 60;

  useEffect(() => {
    let isMounted = true;

    const load = async () => {
      try {
        const snapshot = await userSetupService.loadPricingAvailabilitySnapshot(
          route.params.draftId,
        );

        if (!isMounted) {
          return;
        }

        const nextValues = formatDraftValues(snapshot.draft);
        setDraft(snapshot.draft);
        setLocalDraft(snapshot.draft);
        form.reset(nextValues);
      } catch (loadError) {
        setError(toAuthError(loadError).message);
      }
    };

    void load();

    return () => {
      isMounted = false;
    };
  }, [form, route.params.draftId, setDraft]);

  const submit = form.handleSubmit(async (values) => {
    if (!draft) {
      return;
    }

    setError(null);

    try {
      const updated = await userSetupService.saveHostPricing(draft, values);
      setDraft(updated);
      navigation.replace("HostSpacePhotos", { draftId: updated.id });
    } catch (saveError) {
      setError(toAuthError(saveError).message);
    }
  });

  const toggleFullDay = () => {
    const nextIsFullDay = !isFullDay;

    form.setValue("dailyStartMinute", nextIsFullDay ? 0 : 8 * 60, {
      shouldDirty: true,
      shouldTouch: true,
      shouldValidate: true,
    });
    form.setValue("dailyEndMinute", nextIsFullDay ? 24 * 60 : 21 * 60, {
      shouldDirty: true,
      shouldTouch: true,
      shouldValidate: true,
    });
  };

  return (
    <SetupScaffold
      copyAlign="start"
      description="Set your price, choose one booking window, and define the daily hours renters can use the space."
      error={error}
      primaryDisabled={!draft || !form.formState.isValid}
      primaryLabel="Save and continue"
      primaryLoading={form.formState.isSubmitting}
      progress={0.64}
      showAvatar={false}
      title="Pricing and availability"
      onBack={() =>
        navigation.replace("HostSpaceAddress", {
          draftId: route.params.draftId,
        })
      }
      onPrimaryPress={submit}
    >
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.cardTitle}>Pricing</Text>
          <Text style={styles.cardSubtitle}>
            Choose a practical hourly rate renters can understand at a glance.
          </Text>
        </View>
        <Controller
          control={form.control}
          name="hourlyPrice"
          render={({ field, fieldState }) => (
            <View style={styles.priceField}>
              <Text style={styles.fieldLabel}>Hourly price</Text>
              <View
                style={[
                  styles.priceInputWrap,
                  fieldState.error ? styles.fieldWrapError : null,
                ]}
              >
                <Text style={styles.currency}>Rs</Text>
                <TextInput
                  keyboardType="number-pad"
                  placeholder="50"
                  placeholderTextColor="#8A8A92"
                  style={styles.priceInput}
                  value={asInputNumber(field.value)}
                  onBlur={field.onBlur}
                  onChangeText={field.onChange}
                />
                <Text style={styles.perHour}>/ hour</Text>
              </View>
              {fieldState.error?.message ? (
                <Text style={styles.fieldError}>
                  {fieldState.error.message}
                </Text>
              ) : null}
            </View>
          )}
        />
      </View>

      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.cardTitle}>Availability window</Text>
          <Text style={styles.cardSubtitle}>
            Pick the date range once, then set the daily opening and closing
            hours.
          </Text>
        </View>
        <Controller
          control={form.control}
          name="availableFromDate"
          render={({ fieldState: startFieldState }) => (
            <Controller
              control={form.control}
              name="availableToDate"
              render={({ fieldState: endFieldState }) => (
                <DateRangeCalendar
                  endDate={availableToDate}
                  error={
                    startFieldState.error?.message ??
                    endFieldState.error?.message
                  }
                  startDate={availableFromDate}
                  onChange={({ startDate, endDate }) => {
                    form.setValue("availableFromDate", startDate, {
                      shouldDirty: true,
                      shouldTouch: true,
                      shouldValidate: true,
                    });
                    form.setValue("availableToDate", endDate, {
                      shouldDirty: true,
                      shouldTouch: true,
                      shouldValidate: true,
                    });
                  }}
                />
              )}
            />
          )}
        />
        <View style={styles.fullDayRow}>
          <View style={styles.fullDayCopy}>
            <Text style={styles.fullDayTitle}>Full day</Text>
            <Text style={styles.fullDaySubtitle}>
              Mark this space available for the entire day.
            </Text>
          </View>
          <Pressable
            accessibilityRole="switch"
            accessibilityState={{ checked: isFullDay }}
            style={[
              styles.toggleTrack,
              isFullDay ? styles.toggleTrackActive : null,
            ]}
            onPress={toggleFullDay}
          >
            <View
              style={[
                styles.toggleThumb,
                isFullDay ? styles.toggleThumbActive : null,
              ]}
            />
          </Pressable>
        </View>
        {!isFullDay ? (
          <View style={styles.timeRow}>
            <Controller
              control={form.control}
              name="dailyStartMinute"
              render={({ field, fieldState }) => (
                <TimePickerField
                  error={fieldState.error?.message}
                  label="From"
                  value={field.value}
                  onChange={field.onChange}
                />
              )}
            />
            <Controller
              control={form.control}
              name="dailyEndMinute"
              render={({ field, fieldState }) => (
                <TimePickerField
                  error={fieldState.error?.message}
                  label="To"
                  value={field.value}
                  onChange={field.onChange}
                />
              )}
            />
          </View>
        ) : (
          <View style={styles.fullDayBadge}>
            <Text style={styles.fullDayBadgeLabel}>Hours</Text>
            <Text style={styles.fullDayBadgeValue}>Available all day</Text>
          </View>
        )}
      </View>

      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <Text style={styles.cardTitle}>Space details</Text>
          <Text style={styles.cardSubtitle}>
            Add the real dimensions so the listing attracts the right renters.
          </Text>
        </View>
        <View style={styles.fieldRow}>
          <Controller
            control={form.control}
            name="lengthFeet"
            render={({ field, fieldState }) => (
              <NumberField
                containerStyle={styles.fieldHalf}
                error={fieldState.error?.message}
                keyboardType="decimal-pad"
                label="Length (ft)"
                placeholder="15"
                value={asInputNumber(field.value)}
                onBlur={field.onBlur}
                onChangeText={field.onChange}
              />
            )}
          />
          <Controller
            control={form.control}
            name="widthFeet"
            render={({ field, fieldState }) => (
              <NumberField
                containerStyle={styles.fieldHalf}
                error={fieldState.error?.message}
                keyboardType="decimal-pad"
                label="Width (ft)"
                placeholder="8"
                value={asInputNumber(field.value)}
                onBlur={field.onBlur}
                onChangeText={field.onChange}
              />
            )}
          />
        </View>
        <View style={styles.fieldRow}>
          <Controller
            control={form.control}
            name="heightFeet"
            render={({ field, fieldState }) => (
              <NumberField
                containerStyle={styles.fieldHalf}
                error={fieldState.error?.message}
                keyboardType="decimal-pad"
                label="Height clearance"
                placeholder="Optional"
                value={asInputNumber(field.value)}
                onBlur={field.onBlur}
                onChangeText={field.onChange}
              />
            )}
          />
          <Controller
            control={form.control}
            name="slotsCount"
            render={({ field, fieldState }) => (
              <NumberField
                containerStyle={styles.fieldHalf}
                error={fieldState.error?.message}
                keyboardType="number-pad"
                label="Slots"
                placeholder="1"
                value={asInputNumber(field.value)}
                onBlur={field.onBlur}
                onChangeText={field.onChange}
              />
            )}
          />
        </View>
      </View>
    </SetupScaffold>
  );
}

interface NumberFieldProps {
  containerStyle?: object;
  label: string;
  value: string;
  placeholder: string;
  keyboardType: "decimal-pad" | "number-pad";
  error?: string;
  onBlur: () => void;
  onChangeText: (value: string) => void;
}

function NumberField({
  containerStyle,
  error,
  keyboardType,
  label,
  onBlur,
  onChangeText,
  placeholder,
  value,
}: NumberFieldProps) {
  return (
    <View style={[styles.fieldBlock, containerStyle]}>
      <Text style={styles.fieldLabel}>{label}</Text>
      <TextInput
        keyboardType={keyboardType}
        placeholder={placeholder}
        placeholderTextColor="#8A8A92"
        style={[styles.fieldInput, error ? styles.fieldWrapError : null]}
        value={value}
        onBlur={onBlur}
        onChangeText={onChangeText}
      />
      {error ? <Text style={styles.fieldError}>{error}</Text> : null}
    </View>
  );
}

interface TimePickerFieldProps {
  label: string;
  value: number;
  error?: string;
  onChange: (value: number) => void;
}

function TimePickerField({
  error,
  label,
  onChange,
  value,
}: TimePickerFieldProps) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <View style={styles.timeField}>
        <Text style={styles.fieldLabel}>{label}</Text>
        <Pressable
          accessibilityRole="button"
          style={[styles.timeButton, error ? styles.fieldWrapError : null]}
          onPress={() => setOpen(true)}
        >
          <Text style={styles.timeButtonText}>
            {formatMinutesAsTime(value)}
          </Text>
          <Ionicons color="#111111" name="chevron-down" size={18} />
        </Pressable>
        {error ? <Text style={styles.fieldError}>{error}</Text> : null}
      </View>
      <Modal
        animationType="slide"
        transparent
        visible={open}
        onRequestClose={() => setOpen(false)}
      >
        <View style={styles.modalScrim}>
          <Pressable
            style={StyleSheet.absoluteFill}
            onPress={() => setOpen(false)}
          />
          <View style={styles.modalSheet}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>{label}</Text>
              <Pressable
                accessibilityRole="button"
                hitSlop={8}
                onPress={() => setOpen(false)}
              >
                <Ionicons color="#111111" name="close" size={22} />
              </Pressable>
            </View>
            <ScrollView showsVerticalScrollIndicator={false}>
              {timeSlotOptions.map((option) => {
                const selected = Number(option.value) === value;

                return (
                  <Pressable
                    key={option.value}
                    accessibilityRole="button"
                    accessibilityState={{ selected }}
                    style={[
                      styles.modalOption,
                      selected ? styles.modalOptionSelected : null,
                    ]}
                    onPress={() => {
                      onChange(Number(option.value));
                      setOpen(false);
                    }}
                  >
                    <Text
                      style={[
                        styles.modalOptionText,
                        selected ? styles.modalOptionTextSelected : null,
                      ]}
                    >
                      {option.label}
                    </Text>
                    {selected ? (
                      <Ionicons color="#FFFFFF" name="checkmark" size={18} />
                    ) : null}
                  </Pressable>
                );
              })}
            </ScrollView>
          </View>
        </View>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: "#FFFFFF",
    borderColor: "#ECECF0",
    borderRadius: 24,
    borderWidth: 1,
    gap: 18,
    padding: 18,
    shadowColor: "#0A0A0B",
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.04,
    shadowRadius: 22,
  },
  cardHeader: {
    gap: 6,
  },
  cardTitle: {
    color: "#111111",
    fontSize: 19,
    fontWeight: "900",
  },
  cardSubtitle: {
    color: "#6A6A72",
    fontSize: 13,
    fontWeight: "700",
    lineHeight: 19,
  },
  priceField: {
    gap: 8,
  },
  fieldLabel: {
    color: "#111111",
    fontSize: 13,
    fontWeight: "800",
  },
  priceInputWrap: {
    alignItems: "center",
    backgroundColor: "#FCFCFD",
    borderColor: "#D9DAE0",
    borderRadius: 18,
    borderWidth: 1,
    flexDirection: "row",
    gap: 8,
    minHeight: 70,
    paddingHorizontal: 18,
  },
  currency: {
    color: "#111111",
    fontSize: 22,
    fontWeight: "900",
  },
  priceInput: {
    color: "#111111",
    flex: 1,
    fontSize: 28,
    fontWeight: "900",
    paddingVertical: 0,
  },
  perHour: {
    color: "#6A6A72",
    fontSize: 14,
    fontWeight: "800",
  },
  fullDayRow: {
    alignItems: "center",
    backgroundColor: "#F8F8FA",
    borderRadius: 18,
    flexDirection: "row",
    gap: 12,
    justifyContent: "space-between",
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  fullDayCopy: {
    flex: 1,
    gap: 4,
  },
  fullDayTitle: {
    color: "#111111",
    fontSize: 15,
    fontWeight: "900",
  },
  fullDaySubtitle: {
    color: "#6A6A72",
    fontSize: 13,
    fontWeight: "700",
    lineHeight: 18,
  },
  toggleTrack: {
    backgroundColor: "#D9DAE0",
    borderRadius: 999,
    height: 32,
    justifyContent: "center",
    paddingHorizontal: 3,
    width: 56,
  },
  toggleTrackActive: {
    backgroundColor: "#111111",
  },
  toggleThumb: {
    backgroundColor: "#FFFFFF",
    borderRadius: 13,
    height: 26,
    width: 26,
  },
  toggleThumbActive: {
    alignSelf: "flex-end",
  },
  fullDayBadge: {
    backgroundColor: "#FCFCFD",
    borderColor: "#D9DAE0",
    borderRadius: 16,
    borderWidth: 1,
    gap: 4,
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  fullDayBadgeLabel: {
    color: "#777780",
    fontSize: 11,
    fontWeight: "800",
    textTransform: "uppercase",
  },
  fullDayBadgeValue: {
    color: "#111111",
    fontSize: 15,
    fontWeight: "800",
  },
  timeRow: {
    flexDirection: "row",
    gap: 12,
  },
  timeField: {
    flex: 1,
    gap: 8,
  },
  timeButton: {
    alignItems: "center",
    backgroundColor: "#FCFCFD",
    borderColor: "#D9DAE0",
    borderRadius: 16,
    borderWidth: 1,
    flexDirection: "row",
    justifyContent: "space-between",
    minHeight: 56,
    paddingHorizontal: 16,
  },
  timeButtonText: {
    color: "#111111",
    fontSize: 15,
    fontWeight: "800",
  },
  fieldRow: {
    flexDirection: "row",
    gap: 14,
  },
  fieldBlock: {
    flex: 1,
    gap: 8,
    minWidth: 0,
  },
  fieldHalf: {
    flexBasis: 0,
  },
  fieldInput: {
    backgroundColor: "#FCFCFD",
    borderColor: "#D9DAE0",
    borderRadius: 16,
    borderWidth: 1,
    color: "#111111",
    fontSize: 16,
    fontWeight: "800",
    minHeight: 56,
    paddingHorizontal: 16,
  },
  fieldWrapError: {
    borderColor: "#B42318",
  },
  fieldError: {
    color: "#B42318",
    fontSize: 12,
    fontWeight: "800",
    lineHeight: 18,
  },
  modalScrim: {
    backgroundColor: "rgba(10,10,11,0.28)",
    flex: 1,
    justifyContent: "flex-end",
  },
  modalSheet: {
    backgroundColor: "#FFFFFF",
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: "72%",
    paddingBottom: 24,
    paddingHorizontal: 20,
    paddingTop: 16,
  },
  modalHeader: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 12,
  },
  modalTitle: {
    color: "#111111",
    fontSize: 17,
    fontWeight: "900",
  },
  modalOption: {
    alignItems: "center",
    borderRadius: 16,
    flexDirection: "row",
    justifyContent: "space-between",
    marginBottom: 8,
    paddingHorizontal: 16,
    paddingVertical: 16,
  },
  modalOptionSelected: {
    backgroundColor: "#111111",
  },
  modalOptionText: {
    color: "#111111",
    fontSize: 15,
    fontWeight: "800",
  },
  modalOptionTextSelected: {
    color: "#FFFFFF",
  },
});
