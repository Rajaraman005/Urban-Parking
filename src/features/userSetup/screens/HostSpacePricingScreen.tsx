import { zodResolver } from "@hookform/resolvers/zod";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { useEffect, useState } from "react";
import { Controller, useForm } from "react-hook-form";

import { Input } from "@/components/ui/Input";
import type { RootStackParamList } from "@/core/navigation/types";
import { toAuthError } from "@/features/auth/services/authErrors";
import { BlockedDatesCalendar } from "@/features/userSetup/components/BlockedDatesCalendar";
import { SetupScaffold } from "@/features/userSetup/components/SetupScaffold";
import { WeeklyAvailabilityEditor } from "@/features/userSetup/components/WeeklyAvailabilityEditor";
import {
  hostPricingSchema,
  type HostPricingFormInput,
  type HostPricingValues
} from "@/features/userSetup/schemas/userSetupSchemas";
import { userSetupService } from "@/features/userSetup/services/userSetupService";
import { useUserSetupStore } from "@/features/userSetup/store/userSetupStore";
import type { ParkingSpace } from "@/features/userSetup/types/userSetup.types";
import { defaultAvailabilityRules } from "@/features/userSetup/utils/availability";

type Props = NativeStackScreenProps<RootStackParamList, "HostSpacePricing">;

const asInputNumber = (value: unknown) => (typeof value === "number" || typeof value === "string" ? String(value) : "");

export function HostSpacePricingScreen({ navigation, route }: Props) {
  const setDraft = useUserSetupStore((state) => state.setDraft);
  const [draft, setLocalDraft] = useState<ParkingSpace | null>(null);
  const [error, setError] = useState<string | null>(null);
  const form = useForm<HostPricingFormInput, unknown, HostPricingValues>({
    defaultValues: {
      availabilityRules: defaultAvailabilityRules,
      blockedDates: [],
      heightFeet: undefined,
      hourlyPrice: 50,
      lengthFeet: 15,
      slotsCount: 1,
      widthFeet: 8
    },
    resolver: zodResolver(hostPricingSchema)
  });

  useEffect(() => {
    let isMounted = true;

    const load = async () => {
      try {
        const snapshot = await userSetupService.loadPricingAvailabilitySnapshot(route.params.draftId);

        if (!isMounted) {
          return;
        }

        setDraft(snapshot.draft);
        setLocalDraft(snapshot.draft);
        form.reset({
          availabilityRules:
            snapshot.rules.length > 0
              ? snapshot.rules.map((rule) => ({
                  endMinute: rule.end_minute,
                  startMinute: rule.start_minute,
                  weekday: rule.weekday
                }))
              : defaultAvailabilityRules,
          blockedDates: snapshot.blockedDates,
          heightFeet: snapshot.draft.height_feet ?? undefined,
          hourlyPrice: snapshot.draft.hourly_price ?? 50,
          lengthFeet: snapshot.draft.length_feet ?? 15,
          slotsCount: snapshot.draft.slots_count ?? 1,
          widthFeet: snapshot.draft.width_feet ?? 8
        });
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

  return (
    <SetupScaffold
      description="Set practical dimensions, hourly price, and the exact days renters can book."
      error={error}
      primaryDisabled={!draft}
      primaryLabel="Save and continue"
      primaryLoading={form.formState.isSubmitting}
      progress={0.64}
      title="Pricing and availability"
      onBack={() => navigation.replace("HostSpaceBasics", { draftId: route.params.draftId })}
      onPrimaryPress={submit}
    >
      <Controller
        control={form.control}
        name="hourlyPrice"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            keyboardType="number-pad"
            label="Hourly price"
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="50"
            value={asInputNumber(field.value)}
          />
        )}
      />
      <Controller
        control={form.control}
        name="availabilityRules"
        render={({ field, fieldState }) => (
          <WeeklyAvailabilityEditor
            error={fieldState.error?.message}
            rules={field.value ?? []}
            onChange={field.onChange}
          />
        )}
      />
      <Controller
        control={form.control}
        name="blockedDates"
        render={({ field, fieldState }) => (
          <BlockedDatesCalendar
            blockedDates={field.value ?? []}
            error={fieldState.error?.message}
            onChange={field.onChange}
          />
        )}
      />
      <Controller
        control={form.control}
        name="lengthFeet"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            keyboardType="decimal-pad"
            label="Length in feet"
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="15"
            value={asInputNumber(field.value)}
          />
        )}
      />
      <Controller
        control={form.control}
        name="widthFeet"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            keyboardType="decimal-pad"
            label="Width in feet"
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="8"
            value={asInputNumber(field.value)}
          />
        )}
      />
      <Controller
        control={form.control}
        name="heightFeet"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            keyboardType="decimal-pad"
            label="Height clearance in feet"
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="Optional"
            value={asInputNumber(field.value)}
          />
        )}
      />
      <Controller
        control={form.control}
        name="slotsCount"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            keyboardType="number-pad"
            label="Number of slots"
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="1"
            value={asInputNumber(field.value)}
          />
        )}
      />
    </SetupScaffold>
  );
}
