import { zodResolver } from "@hookform/resolvers/zod";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { useEffect, useState } from "react";
import { Controller, useForm } from "react-hook-form";

import { Input } from "@/components/ui/Input";
import type { RootStackParamList } from "@/core/navigation/types";
import { toAuthError } from "@/features/auth/services/authErrors";
import { SelectField, type SelectOption } from "@/features/userSetup/components/SelectField";
import { SetupScaffold } from "@/features/userSetup/components/SetupScaffold";
import { hostBasicsSchema, type HostBasicsValues } from "@/features/userSetup/schemas/userSetupSchemas";
import { userSetupService } from "@/features/userSetup/services/userSetupService";
import { useUserSetupStore } from "@/features/userSetup/store/userSetupStore";
import type { ParkingSpace, ParkingType, VehicleFit } from "@/features/userSetup/types/userSetup.types";

type Props = NativeStackScreenProps<RootStackParamList, "HostSpaceBasics">;

const parkingTypes: SelectOption<ParkingType>[] = [
  { label: "Covered", value: "covered" },
  { label: "Open", value: "open" },
  { label: "Garage", value: "garage" },
  { label: "Driveway", value: "driveway" },
  { label: "Basement", value: "basement" }
];

const vehicleFits: SelectOption<VehicleFit>[] = [
  { label: "Bike", value: "bike" },
  { label: "Car", value: "car" },
  { label: "Both", value: "both" }
];

export function HostSpaceBasicsScreen({ navigation, route }: Props) {
  const setDraft = useUserSetupStore((state) => state.setDraft);
  const [draft, setLocalDraft] = useState<ParkingSpace | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [openSelect, setOpenSelect] = useState<"vehicleFit" | "parkingType" | null>(null);
  const form = useForm<HostBasicsValues>({
    defaultValues: {
      address: "",
      city: "",
      landmark: "",
      locality: "",
      parkingType: "covered",
      postalCode: "",
      vehicleFit: "car"
    },
    resolver: zodResolver(hostBasicsSchema)
  });

  useEffect(() => {
    let isMounted = true;

    const load = async () => {
      try {
        const resolvedDraft = route.params?.draftId
          ? await userSetupService.loadDraft(route.params.draftId)
          : await userSetupService.getOrCreateHostDraft();

        if (!isMounted) {
          return;
        }

        setDraft(resolvedDraft);
        setLocalDraft(resolvedDraft);
        form.reset({
          address: resolvedDraft.address ?? "",
          city: resolvedDraft.city ?? "",
          landmark: resolvedDraft.landmark ?? "",
          locality: resolvedDraft.locality ?? "",
          parkingType: resolvedDraft.parking_type ?? "covered",
          postalCode: resolvedDraft.postal_code ?? "",
          vehicleFit: resolvedDraft.vehicle_fit ?? "car"
        });
      } catch (loadError) {
        setError(toAuthError(loadError).message);
      }
    };

    void load();

    return () => {
      isMounted = false;
    };
  }, [form, route.params?.draftId, setDraft]);

  const submit = form.handleSubmit(async (values) => {
    if (!draft) {
      return;
    }

    setError(null);

    try {
      const updated = await userSetupService.saveHostBasics(draft, values);
      setDraft(updated);
      navigation.replace("HostSpacePricing", { draftId: updated.id });
    } catch (saveError) {
      setError(toAuthError(saveError).message);
    }
  });

  return (
    <SetupScaffold
      description="Add the physical details renters need before they book. The exact address stays protected until booking rules are ready."
      error={error}
      primaryDisabled={!draft}
      primaryLabel="Save and continue"
      primaryLoading={form.formState.isSubmitting}
      progress={0.48}
      title="Where is your space?"
      onBack={() => navigation.replace("UserSetupProfile", { intent: "host" })}
      onPrimaryPress={submit}
    >
      <Controller
        control={form.control}
        name="address"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            label="Full address"
            multiline
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="Apartment, street, area"
            value={field.value}
          />
        )}
      />
      <Controller
        control={form.control}
        name="locality"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            label="Locality"
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="Nearby area"
            value={field.value}
          />
        )}
      />
      <Controller
        control={form.control}
        name="city"
        render={({ field, fieldState }) => (
          <Input
            autoCapitalize="words"
            error={fieldState.error?.message}
            label="City"
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="City"
            value={field.value}
          />
        )}
      />
      <Controller
        control={form.control}
        name="postalCode"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            keyboardType="number-pad"
            label="Postal code"
            maxLength={6}
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="600001"
            textContentType="postalCode"
            value={field.value}
          />
        )}
      />
      <Controller
        control={form.control}
        name="landmark"
        render={({ field, fieldState }) => (
          <Input
            error={fieldState.error?.message}
            label="Landmark"
            onBlur={field.onBlur}
            onChangeText={field.onChange}
            placeholder="Optional"
            value={field.value ?? ""}
          />
        )}
      />
      <Controller
        control={form.control}
        name="vehicleFit"
        render={({ field, fieldState }) => (
          <SelectField
            error={fieldState.error?.message}
            label="Vehicle fit"
            open={openSelect === "vehicleFit"}
            options={vehicleFits}
            value={field.value}
            onChange={field.onChange}
            onOpenChange={(isOpen) => setOpenSelect(isOpen ? "vehicleFit" : null)}
          />
        )}
      />
      <Controller
        control={form.control}
        name="parkingType"
        render={({ field, fieldState }) => (
          <SelectField
            error={fieldState.error?.message}
            label="Parking type"
            open={openSelect === "parkingType"}
            options={parkingTypes}
            value={field.value}
            onChange={field.onChange}
            onOpenChange={(isOpen) => setOpenSelect(isOpen ? "parkingType" : null)}
          />
        )}
      />
    </SetupScaffold>
  );
}
