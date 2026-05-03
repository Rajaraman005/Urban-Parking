import { Ionicons } from "@expo/vector-icons";
import { zodResolver } from "@hookform/resolvers/zod";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { StatusBar } from "expo-status-bar";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Controller, useForm, type Path, type PathValue } from "react-hook-form";
import {
  ActivityIndicator,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View
} from "react-native";
import { KeyboardAvoidingView } from "react-native-keyboard-controller";
import { SafeAreaView } from "react-native-safe-area-context";

import { Button } from "@/components/ui/Button";
import type { RootStackParamList } from "@/core/navigation/types";
import { toAuthError } from "@/features/auth/services/authErrors";
import { hostBasicsSchema, type HostBasicsValues } from "@/features/userSetup/schemas/userSetupSchemas";
import { userSetupService } from "@/features/userSetup/services/userSetupService";
import { useUserSetupStore } from "@/features/userSetup/store/userSetupStore";
import type { NormalizedAddressResult, ParkingSpace } from "@/features/userSetup/types/userSetup.types";

type Props = NativeStackScreenProps<RootStackParamList, "HostSpaceAddress">;

type AddressLabel = "House" | "Office" | "Other";

const emptyCoordinate = Number.NaN;

const defaultHostBasicsValues: HostBasicsValues = {
  accessInstructions: "",
  address: "",
  addressConfidence: 0.45,
  addressPlaceId: null,
  addressProvider: "manual",
  addressRawOsmJson: null,
  city: "",
  landmark: "",
  latitude: emptyCoordinate,
  locality: "",
  locationConfirmedAt: "",
  longitude: emptyCoordinate,
  parkingType: "covered",
  postalCode: "",
  vehicleFit: "car"
};

const addressLabels: { icon: keyof typeof Ionicons.glyphMap; label: AddressLabel }[] = [
  { icon: "home-outline", label: "House" },
  { icon: "briefcase-outline", label: "Office" },
  { icon: "navigate", label: "Other" }
];

const formatDraftValues = (draft: ParkingSpace): HostBasicsValues => ({
  accessInstructions: draft.access_instructions ?? "",
  address: draft.address ?? "",
  addressConfidence: draft.address_confidence ?? 0.45,
  addressPlaceId: draft.address_place_id ?? null,
  addressProvider: draft.address_provider ?? "manual",
  addressRawOsmJson: draft.address_raw_osm_json ?? null,
  city: draft.city ?? "",
  landmark: draft.landmark ?? "",
  latitude: draft.latitude ?? emptyCoordinate,
  locality: draft.locality ?? "",
  locationConfirmedAt: draft.location_confirmed_at ?? "",
  longitude: draft.longitude ?? emptyCoordinate,
  parkingType: draft.parking_type ?? "covered",
  postalCode: draft.postal_code ?? "",
  vehicleFit: draft.vehicle_fit ?? "car"
});

const getDisplayAddress = (values: HostBasicsValues) =>
  [values.address, values.locality, values.city, values.postalCode].filter(Boolean).join(", ");

const hasValidCoordinate = (latitude: unknown, longitude: unknown) =>
  typeof latitude === "number" &&
  typeof longitude === "number" &&
  Number.isFinite(latitude) &&
  Number.isFinite(longitude);

const getFieldBorderColor = (error?: string) => (error ? "#B42318" : "#DEDEE3");

export function HostSpaceAddressScreen({ navigation, route }: Props) {
  const setDraft = useUserSetupStore((state) => state.setDraft);
  const [draft, setLocalDraft] = useState<ParkingSpace | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [lookupError, setLookupError] = useState<string | null>(null);
  const [results, setResults] = useState<NormalizedAddressResult[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [addressLabel, setAddressLabel] = useState<AddressLabel>("House");
  const [isSearching, setIsSearching] = useState(false);
  const [showSearch, setShowSearch] = useState(false);

  const form = useForm<HostBasicsValues>({
    defaultValues: defaultHostBasicsValues,
    resolver: zodResolver(hostBasicsSchema)
  });

  const latitude = form.watch("latitude");
  const longitude = form.watch("longitude");
  const selectedAddress = form.watch("address");
  const selectedCity = form.watch("city");
  const selectedLandmark = form.watch("landmark");
  const selectedLocality = form.watch("locality");
  const selectedPostalCode = form.watch("postalCode");
  const hasRequiredAddressParts = Boolean(
    selectedLandmark.trim() &&
      selectedAddress.trim() &&
      selectedLocality.trim() &&
      selectedCity.trim() &&
      /^[1-9]\d{5}$/.test(selectedPostalCode.trim())
  );
  const canContinue = Boolean(draft && hasValidCoordinate(latitude, longitude) && hasRequiredAddressParts && !isSearching);
  const headerTitle = selectedLocality || selectedCity || "Selected location";
  const headerSubtitle = [selectedCity, selectedPostalCode].filter(Boolean).join(" ");
  const areaAddress = useMemo(
    () => [selectedLocality, selectedCity, selectedPostalCode].filter(Boolean).join(", "),
    [selectedCity, selectedLocality, selectedPostalCode]
  );

  const setFormValue = useCallback(
    <TField extends Path<HostBasicsValues>>(field: TField, value: PathValue<HostBasicsValues, TField>, shouldValidate = true) => {
      form.setValue(field, value, {
        shouldDirty: true,
        shouldTouch: true,
        shouldValidate
      });
    },
    [form]
  );

  const setManualAddressSource = useCallback(() => {
    setFormValue("addressProvider", "manual", false);
    setFormValue("addressConfidence", 0.45, false);
    setFormValue("addressPlaceId", null, false);
    setFormValue("addressRawOsmJson", null, false);
  }, [setFormValue]);

  const applyAddressResult = useCallback(
    (result: NormalizedAddressResult) => {
      const nextAddress = result.formattedAddress || form.getValues("address");

      setFormValue("address", nextAddress);
      setFormValue("locality", result.locality ?? form.getValues("locality"));
      setFormValue("city", result.city ?? form.getValues("city"));
      setFormValue("postalCode", result.postalCode ?? form.getValues("postalCode"));
      setFormValue("latitude", result.latitude);
      setFormValue("longitude", result.longitude);
      setFormValue("addressConfidence", result.confidence);
      setFormValue("addressPlaceId", result.placeId);
      setFormValue("addressProvider", result.provider);
      setFormValue("addressRawOsmJson", result.raw ?? null, false);
      setFormValue("locationConfirmedAt", new Date().toISOString());
      setSearchQuery(nextAddress);
      setLookupError(null);
      setResults([]);
      setShowSearch(false);
    },
    [form, setFormValue]
  );

  useEffect(() => {
    let isMounted = true;

    const load = async () => {
      try {
        const resolvedDraft = await userSetupService.loadDraft(route.params.draftId);

        if (!isMounted) {
          return;
        }

        const draftValues = formatDraftValues(resolvedDraft);
        setDraft(resolvedDraft);
        setLocalDraft(resolvedDraft);
        form.reset(draftValues);
        setSearchQuery(getDisplayAddress(draftValues));
      } catch (loadError) {
        setError(toAuthError(loadError).message);
      }
    };

    void load();

    return () => {
      isMounted = false;
    };
  }, [form, route.params.draftId, setDraft]);

  const handleSearch = useCallback(async () => {
    const fallbackQuery = getDisplayAddress(form.getValues());
    const query = (searchQuery.trim() || fallbackQuery).trim();

    if (query.length < 4) {
      setLookupError("Enter at least four characters before searching.");
      return;
    }

    setIsSearching(true);
    setLookupError(null);
    setResults([]);

    try {
      const response = await userSetupService.searchAddress(query);
      setResults(response.results);

      if (response.results.length === 0) {
        setManualAddressSource();
        setLookupError("No exact match found. Type the address manually or search again.");
      }
    } catch (searchError) {
      setLookupError(toAuthError(searchError).message);
    } finally {
      setIsSearching(false);
    }
  }, [form, searchQuery, setManualAddressSource]);

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
    <SafeAreaView style={styles.screen}>
      <StatusBar backgroundColor="#FFFFFF" style="dark" translucent={false} />
      <KeyboardAvoidingView
        behavior="padding"
        keyboardVerticalOffset={Platform.OS === "ios" ? 8 : 0}
        style={styles.keyboard}
      >
        <View style={styles.header}>
          <Pressable
            accessibilityLabel="Back to map"
            accessibilityRole="button"
            hitSlop={10}
            style={styles.headerBack}
            onPress={() => navigation.replace("HostSpaceBasics", { draftId: route.params.draftId })}
          >
            <Ionicons color="#0A0A0B" name="arrow-back" size={24} />
          </Pressable>
          <View style={styles.headerCopy}>
            <Text numberOfLines={1} style={styles.headerTitle}>
              {headerTitle}
              {headerSubtitle ? <Text style={styles.headerMuted}> | {headerSubtitle}</Text> : null}
            </Text>
          </View>
        </View>

        <ScrollView
          style={styles.scroll}
          contentContainerStyle={styles.content}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <Text style={styles.sectionTitle}>Location Details</Text>
          <View style={styles.sectionCard}>
            <View style={styles.segmentedControl}>
              {addressLabels.map((item) => {
                const selected = addressLabel === item.label;

                return (
                  <Pressable
                    key={item.label}
                    accessibilityRole="button"
                    accessibilityState={{ selected }}
                    style={[styles.segmentButton, selected ? styles.segmentButtonSelected : null]}
                    onPress={() => setAddressLabel(item.label)}
                  >
                    <Ionicons color={selected ? "#FFFFFF" : "#0A0A0B"} name={item.icon} size={16} />
                    <Text style={[styles.segmentText, selected ? styles.segmentTextSelected : null]}>{item.label}</Text>
                  </Pressable>
                );
              })}
            </View>

            <Controller
              control={form.control}
              name="landmark"
              render={({ field, fieldState }) => (
                <View style={styles.fieldBlock}>
                  <TextInput
                    placeholder="Building / Floor *"
                    placeholderTextColor="#77777D"
                    returnKeyType="next"
                    style={[styles.fieldInput, { borderColor: getFieldBorderColor(fieldState.error?.message) }]}
                    value={field.value ?? ""}
                    onBlur={field.onBlur}
                    onChangeText={field.onChange}
                  />
                  {fieldState.error?.message ? <Text style={styles.fieldError}>{fieldState.error.message}</Text> : null}
                </View>
              )}
            />

            <Controller
              control={form.control}
              name="address"
              render={({ field, fieldState }) => (
                <View style={styles.fieldBlock}>
                  <TextInput
                    multiline
                    placeholder="Full address *"
                    placeholderTextColor="#77777D"
                    style={[
                      styles.fieldInput,
                      styles.fullAddressInput,
                      { borderColor: getFieldBorderColor(fieldState.error?.message) }
                    ]}
                    textAlignVertical="top"
                    value={field.value}
                    onBlur={field.onBlur}
                    onChangeText={field.onChange}
                  />
                  {fieldState.error?.message ? <Text style={styles.fieldError}>{fieldState.error.message}</Text> : null}
                </View>
              )}
            />

            <View style={styles.areaRow}>
              <View style={styles.areaCard}>
                <Text style={styles.areaLabel}>Area/Locality</Text>
                <Text numberOfLines={2} style={styles.areaText}>
                  {areaAddress || "Area, city and PIN code"}
                </Text>
              </View>
              <Pressable
                accessibilityRole="button"
                style={styles.changeMapCard}
                onPress={() => setShowSearch((value) => !value)}
              >
                <View style={styles.mapLineOne} />
                <View style={styles.mapLineTwo} />
                <Ionicons color="#0A0A0B" name="location" size={26} />
                <Text style={styles.changeText}>Change</Text>
              </Pressable>
            </View>

            {showSearch ? (
              <View style={styles.searchPanel}>
                <View style={styles.searchRow}>
                  <TextInput
                    placeholder="Search area, street, city"
                    placeholderTextColor="#77777D"
                    returnKeyType="search"
                    style={styles.searchInput}
                    value={searchQuery}
                    onChangeText={setSearchQuery}
                    onSubmitEditing={handleSearch}
                  />
                  <Pressable
                    accessibilityRole="button"
                    disabled={isSearching}
                    style={[styles.searchButton, isSearching ? styles.searchButtonDisabled : null]}
                    onPress={handleSearch}
                  >
                    {isSearching ? (
                      <ActivityIndicator color="#FFFFFF" size="small" />
                    ) : (
                      <Ionicons color="#FFFFFF" name="search" size={20} />
                    )}
                  </Pressable>
                </View>

                {results.length > 0 ? (
                  <View style={styles.results}>
                    {results.map((result) => (
                      <Pressable
                        key={`${result.provider}-${result.placeId ?? result.latitude}-${result.longitude}`}
                        accessibilityRole="button"
                        style={styles.resultCard}
                        onPress={() => applyAddressResult(result)}
                      >
                        <View style={styles.resultIcon}>
                          <Ionicons color="#0A0A0B" name="location" size={15} />
                        </View>
                        <View style={styles.resultCopy}>
                          <Text numberOfLines={2} style={styles.resultTitle}>
                            {result.formattedAddress}
                          </Text>
                          <Text style={styles.resultMeta}>
                            {[result.locality, result.city, result.postalCode].filter(Boolean).join(" - ") || "India"}
                          </Text>
                        </View>
                      </Pressable>
                    ))}
                  </View>
                ) : null}
              </View>
            ) : null}

            <View style={styles.inlineFields}>
              <Controller
                control={form.control}
                name="locality"
                render={({ field, fieldState }) => (
                  <View style={[styles.inlineFieldBlock, styles.inlineFieldGrow]}>
                    <TextInput
                      placeholder="Locality *"
                      placeholderTextColor="#77777D"
                      style={[styles.fieldInput, { borderColor: getFieldBorderColor(fieldState.error?.message) }]}
                      value={field.value}
                      onBlur={field.onBlur}
                      onChangeText={field.onChange}
                    />
                    {fieldState.error?.message ? <Text style={styles.fieldError}>{fieldState.error.message}</Text> : null}
                  </View>
                )}
              />
              <Controller
                control={form.control}
                name="postalCode"
                render={({ field, fieldState }) => (
                  <View style={styles.pinField}>
                    <TextInput
                      keyboardType="number-pad"
                      maxLength={6}
                      placeholder="PIN *"
                      placeholderTextColor="#77777D"
                      style={[styles.fieldInput, { borderColor: getFieldBorderColor(fieldState.error?.message) }]}
                      value={field.value}
                      onBlur={field.onBlur}
                      onChangeText={field.onChange}
                    />
                    {fieldState.error?.message ? <Text style={styles.fieldError}>{fieldState.error.message}</Text> : null}
                  </View>
                )}
              />
            </View>

            <Controller
              control={form.control}
              name="city"
              render={({ field, fieldState }) => (
                <View style={styles.fieldBlock}>
                  <TextInput
                    autoCapitalize="words"
                    placeholder="City *"
                    placeholderTextColor="#77777D"
                    style={[styles.fieldInput, { borderColor: getFieldBorderColor(fieldState.error?.message) }]}
                    value={field.value}
                    onBlur={field.onBlur}
                    onChangeText={field.onChange}
                  />
                  {fieldState.error?.message ? <Text style={styles.fieldError}>{fieldState.error.message}</Text> : null}
                </View>
              )}
            />
          </View>

          <Text style={styles.sectionTitle}>Parking Instructions</Text>
          <View style={styles.instructionCard}>
            <View style={styles.instructionHeader}>
              <Text style={styles.instructionHint}>Instructions to reach location</Text>
              <Text style={styles.instructionAction}>Optional</Text>
            </View>
            <Controller
              control={form.control}
              name="accessInstructions"
              render={({ field, fieldState }) => (
                <View style={styles.fieldBlock}>
                  <TextInput
                    multiline
                    placeholder="Add gate notes, floor details, landmark cues, or how renters should enter."
                    placeholderTextColor="#77777D"
                    style={[
                      styles.fieldInput,
                      styles.instructionsInput,
                      { borderColor: getFieldBorderColor(fieldState.error?.message) }
                    ]}
                    textAlignVertical="top"
                    value={field.value ?? ""}
                    onBlur={field.onBlur}
                    onChangeText={field.onChange}
                  />
                  {fieldState.error?.message ? <Text style={styles.fieldError}>{fieldState.error.message}</Text> : null}
                </View>
              )}
            />
          </View>

          {lookupError ? <Text style={styles.lookupError}>{lookupError}</Text> : null}
          {error ? <Text style={styles.lookupError}>{error}</Text> : null}
          {!hasValidCoordinate(latitude, longitude) ? (
            <Text style={styles.helperText}>Go back and place the map pin before saving this address.</Text>
          ) : null}
        </ScrollView>

        <View style={styles.footer}>
          <Button
            disabled={!canContinue}
            label="Save and continue"
            loading={form.formState.isSubmitting}
            style={styles.footerButton}
            onPress={submit}
          />
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: "#F1F1F5"
  },
  keyboard: {
    flex: 1
  },
  header: {
    minHeight: 56,
    alignItems: "center",
    flexDirection: "row",
    gap: 8,
    paddingHorizontal: 18,
    borderBottomWidth: 1,
    borderBottomColor: "#EFEFF3",
    backgroundColor: "#FFFFFF"
  },
  headerBack: {
    width: 32,
    height: 32,
    alignItems: "center",
    justifyContent: "center"
  },
  headerCopy: {
    flex: 1
  },
  headerTitle: {
    color: "#111114",
    fontSize: 15,
    fontWeight: "900",
    lineHeight: 20
  },
  headerMuted: {
    color: "#8A8A91",
    fontWeight: "800"
  },
  scroll: {
    flex: 1
  },
  content: {
    paddingHorizontal: 20,
    paddingTop: 20,
    paddingBottom: 116,
    gap: 12
  },
  sectionTitle: {
    color: "#111114",
    fontSize: 17,
    fontWeight: "900",
    lineHeight: 23,
    marginTop: 4
  },
  sectionCard: {
    gap: 14,
    padding: 12,
    borderRadius: 8,
    backgroundColor: "#FFFFFF"
  },
  segmentedControl: {
    minHeight: 40,
    flexDirection: "row",
    gap: 4,
    padding: 4,
    borderRadius: 8,
    backgroundColor: "#F0F0F4"
  },
  segmentButton: {
    flex: 1,
    minHeight: 32,
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "center",
    gap: 6,
    borderRadius: 8
  },
  segmentButtonSelected: {
    backgroundColor: "#0A0A0B"
  },
  segmentText: {
    color: "#0A0A0B",
    fontSize: 13,
    fontWeight: "900"
  },
  segmentTextSelected: {
    color: "#FFFFFF"
  },
  fieldBlock: {
    gap: 6
  },
  fieldInput: {
    minHeight: 50,
    borderWidth: 1,
    borderRadius: 8,
    backgroundColor: "#FFFFFF",
    color: "#111114",
    fontSize: 15,
    fontWeight: "800",
    paddingHorizontal: 16
  },
  fullAddressInput: {
    minHeight: 78,
    paddingTop: 14
  },
  fieldError: {
    color: "#B42318",
    fontSize: 12,
    fontWeight: "800",
    lineHeight: 17
  },
  areaRow: {
    minHeight: 80,
    flexDirection: "row",
    gap: 10
  },
  areaCard: {
    flex: 1,
    justifyContent: "center",
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#DEDEE3",
    backgroundColor: "#FFFFFF"
  },
  areaLabel: {
    position: "absolute",
    top: -9,
    left: 12,
    paddingHorizontal: 5,
    color: "#77777D",
    fontSize: 12,
    fontWeight: "800",
    backgroundColor: "#FFFFFF"
  },
  areaText: {
    color: "#9A9AA0",
    fontSize: 15,
    fontWeight: "900",
    lineHeight: 21
  },
  changeMapCard: {
    width: 84,
    alignItems: "center",
    justifyContent: "center",
    overflow: "hidden",
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#DEDEE3",
    backgroundColor: "#F7F7FA"
  },
  mapLineOne: {
    position: "absolute",
    width: 118,
    height: 2,
    top: 25,
    left: -18,
    transform: [{ rotate: "-28deg" }],
    backgroundColor: "#DFDFE6"
  },
  mapLineTwo: {
    position: "absolute",
    width: 112,
    height: 2,
    bottom: 23,
    left: -10,
    transform: [{ rotate: "22deg" }],
    backgroundColor: "#DFDFE6"
  },
  changeText: {
    color: "#0A0A0B",
    fontSize: 12,
    fontWeight: "900"
  },
  searchPanel: {
    gap: 10
  },
  searchRow: {
    alignItems: "center",
    flexDirection: "row",
    gap: 10
  },
  searchInput: {
    flex: 1,
    minHeight: 50,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#DEDEE3",
    backgroundColor: "#FFFFFF",
    color: "#111114",
    fontSize: 15,
    fontWeight: "800",
    paddingHorizontal: 14
  },
  searchButton: {
    width: 50,
    height: 50,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 8,
    backgroundColor: "#0A0A0B"
  },
  searchButtonDisabled: {
    opacity: 0.55
  },
  results: {
    gap: 8
  },
  resultCard: {
    minHeight: 64,
    alignItems: "center",
    flexDirection: "row",
    gap: 10,
    padding: 10,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#ECECEC",
    backgroundColor: "#FAFAFA"
  },
  resultIcon: {
    width: 32,
    height: 32,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 16,
    backgroundColor: "#FFFFFF"
  },
  resultCopy: {
    flex: 1,
    gap: 3
  },
  resultTitle: {
    color: "#0A0A0B",
    fontSize: 13,
    fontWeight: "900",
    lineHeight: 18
  },
  resultMeta: {
    color: "#777777",
    fontSize: 12,
    fontWeight: "700"
  },
  inlineFields: {
    flexDirection: "row",
    gap: 10
  },
  inlineFieldBlock: {
    gap: 6
  },
  inlineFieldGrow: {
    flex: 1
  },
  pinField: {
    width: 104,
    gap: 6
  },
  instructionCard: {
    gap: 12,
    padding: 14,
    borderRadius: 8,
    backgroundColor: "#FFFFFF"
  },
  instructionHeader: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    gap: 12
  },
  instructionHint: {
    flex: 1,
    color: "#66666C",
    fontSize: 13,
    fontWeight: "800",
    lineHeight: 18
  },
  instructionAction: {
    color: "#0A0A0B",
    fontSize: 13,
    fontWeight: "900"
  },
  instructionsInput: {
    minHeight: 108,
    paddingTop: 14,
    paddingBottom: 14
  },
  lookupError: {
    color: "#B42318",
    fontSize: 13,
    fontWeight: "800",
    lineHeight: 19
  },
  helperText: {
    color: "#777777",
    fontSize: 12,
    fontWeight: "800",
    lineHeight: 18
  },
  footer: {
    paddingHorizontal: 20,
    paddingTop: 10,
    paddingBottom: 20,
    borderTopWidth: 1,
    borderTopColor: "#E8E8EE",
    backgroundColor: "#FFFFFF"
  },
  footerButton: {
    height: 58,
    borderRadius: 8
  }
});
