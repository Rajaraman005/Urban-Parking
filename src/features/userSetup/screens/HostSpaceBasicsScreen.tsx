import { Ionicons } from "@expo/vector-icons";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import * as Location from "expo-location";
import { StatusBar } from "expo-status-bar";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { Button } from "@/components/ui/Button";
import type { RootStackParamList } from "@/core/navigation/types";
import { toAuthError } from "@/features/auth/services/authErrors";
import { OpenStreetAddressPicker } from "@/features/userSetup/components/OpenStreetAddressPicker";
import { hostLocationSchema, type HostLocationValues } from "@/features/userSetup/schemas/userSetupSchemas";
import { userSetupService } from "@/features/userSetup/services/userSetupService";
import { useUserSetupStore } from "@/features/userSetup/store/userSetupStore";
import type { NormalizedAddressResult, ParkingSpace } from "@/features/userSetup/types/userSetup.types";

type Props = NativeStackScreenProps<RootStackParamList, "HostSpaceBasics">;

interface Coordinates {
  latitude: number;
  longitude: number;
}

const INDIA_BOUNDS = {
  maxLatitude: 38,
  maxLongitude: 98,
  minLatitude: 6,
  minLongitude: 68
} as const;

const isIndiaCoordinate = (latitude: unknown, longitude: unknown): latitude is number =>
  typeof latitude === "number" &&
  typeof longitude === "number" &&
  Number.isFinite(latitude) &&
  Number.isFinite(longitude) &&
  latitude >= INDIA_BOUNDS.minLatitude &&
  latitude <= INDIA_BOUNDS.maxLatitude &&
  longitude >= INDIA_BOUNDS.minLongitude &&
  longitude <= INDIA_BOUNDS.maxLongitude;

const formatDraftAddress = (draft: ParkingSpace) =>
  [draft.address, draft.locality, draft.city, draft.postal_code].filter(Boolean).join(", ");

const getDraftCoordinates = (draft: ParkingSpace): Coordinates | null => {
  const { latitude, longitude } = draft;

  return isIndiaCoordinate(latitude, longitude) && typeof longitude === "number"
    ? {
        latitude,
        longitude
      }
    : null;
};

const getDraftPreview = (draft: ParkingSpace): NormalizedAddressResult | null => {
  const coordinates = getDraftCoordinates(draft);
  const formattedAddress = formatDraftAddress(draft);

  if (!coordinates || !formattedAddress) {
    return null;
  }

  return {
    city: draft.city,
    confidence: draft.address_confidence ?? 0.45,
    formattedAddress,
    latitude: coordinates.latitude,
    locality: draft.locality,
    longitude: coordinates.longitude,
    placeId: draft.address_place_id,
    postalCode: draft.postal_code,
    provider: draft.address_provider ?? "manual",
    raw: draft.address_raw_osm_json
  };
};

const toLocationValues = (coordinates: Coordinates, preview: NormalizedAddressResult | null): HostLocationValues => ({
  address: preview?.formattedAddress || undefined,
  addressConfidence: preview?.confidence ?? 0.45,
  addressPlaceId: preview?.placeId ?? null,
  addressProvider: preview?.provider ?? "manual",
  addressRawOsmJson: preview?.raw ?? null,
  city: preview?.city ?? undefined,
  latitude: coordinates.latitude,
  locality: preview?.locality ?? undefined,
  locationConfirmedAt: new Date().toISOString(),
  longitude: coordinates.longitude,
  postalCode: preview?.postalCode && /^[1-9]\d{5}$/.test(preview.postalCode) ? preview.postalCode : undefined
});

export function HostSpaceBasicsScreen({ navigation, route }: Props) {
  const setDraft = useUserSetupStore((state) => state.setDraft);
  const [draft, setLocalDraft] = useState<ParkingSpace | null>(null);
  const [coordinates, setCoordinates] = useState<Coordinates | null>(null);
  const [preview, setPreview] = useState<NormalizedAddressResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [lookupError, setLookupError] = useState<string | null>(null);
  const [isLocating, setIsLocating] = useState(false);
  const [isReverseGeocoding, setIsReverseGeocoding] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const reverseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reverseRequestIdRef = useRef(0);

  const hasCoordinate = Boolean(coordinates && isIndiaCoordinate(coordinates.latitude, coordinates.longitude));
  const previewTitle = preview?.locality || preview?.city || (hasCoordinate ? "Selected location" : "Choose location");
  const previewSubtitle = useMemo(() => {
    if (preview?.city || preview?.postalCode) {
      return [preview.city, preview.postalCode].filter(Boolean).join(" - ");
    }

    if (preview?.formattedAddress) {
      return preview.formattedAddress;
    }

    return hasCoordinate ? "Confirm and add the full address next" : "Use current location or tap the map";
  }, [hasCoordinate, preview]);

  const clearReverseTimer = useCallback(() => {
    if (reverseTimerRef.current) {
      clearTimeout(reverseTimerRef.current);
      reverseTimerRef.current = null;
    }
  }, []);

  const runReverseGeocode = useCallback(async (nextCoordinates: Coordinates) => {
    if (!isIndiaCoordinate(nextCoordinates.latitude, nextCoordinates.longitude)) {
      setLookupError("Choose a location inside India.");
      return;
    }

    const requestId = reverseRequestIdRef.current + 1;
    reverseRequestIdRef.current = requestId;
    setIsReverseGeocoding(true);
    setLookupError(null);

    try {
      const response = await userSetupService.reverseGeocodeAddress(nextCoordinates.latitude, nextCoordinates.longitude);

      if (reverseRequestIdRef.current !== requestId) {
        return;
      }

      setPreview(response.result);
    } catch (reverseError) {
      if (reverseRequestIdRef.current !== requestId) {
        return;
      }

      setPreview(null);
      setLookupError(`${toAuthError(reverseError).message} You can still continue and type the address next.`);
    } finally {
      if (reverseRequestIdRef.current === requestId) {
        setIsReverseGeocoding(false);
      }
    }
  }, []);

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
        setCoordinates(getDraftCoordinates(resolvedDraft));
        setPreview(getDraftPreview(resolvedDraft));
      } catch (loadError) {
        setError(toAuthError(loadError).message);
      }
    };

    void load();

    return () => {
      isMounted = false;
      clearReverseTimer();
    };
  }, [clearReverseTimer, route.params?.draftId, setDraft]);

  const handlePinChanged = useCallback(
    (nextCoordinates: Coordinates) => {
      clearReverseTimer();
      setCoordinates(nextCoordinates);
      setPreview(null);
      setLookupError(null);
      reverseTimerRef.current = setTimeout(() => {
        void runReverseGeocode(nextCoordinates);
      }, 700);
    },
    [clearReverseTimer, runReverseGeocode]
  );

  const handleUseCurrentLocation = useCallback(async () => {
    setIsLocating(true);
    setLookupError(null);

    try {
      const permission = await Location.requestForegroundPermissionsAsync();

      if (permission.status !== Location.PermissionStatus.GRANTED) {
        setLookupError("Location permission was denied. You can tap the map to place the pin manually.");
        return;
      }

      const position = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.Balanced
      });
      const nextCoordinates = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude
      };

      if (!isIndiaCoordinate(nextCoordinates.latitude, nextCoordinates.longitude)) {
        setLookupError("Your current location is outside India.");
        return;
      }

      clearReverseTimer();
      setCoordinates(nextCoordinates);
      setPreview(null);
      await runReverseGeocode(nextCoordinates);
    } catch (locationError) {
      setLookupError(toAuthError(locationError).message);
    } finally {
      setIsLocating(false);
    }
  }, [clearReverseTimer, runReverseGeocode]);

  const handleConfirm = useCallback(async () => {
    if (!draft || !coordinates) {
      setLookupError("Place the pin before continuing.");
      return;
    }

    const parsed = hostLocationSchema.safeParse(toLocationValues(coordinates, preview));

    if (!parsed.success) {
      setLookupError(parsed.error.issues[0]?.message ?? "Confirm the map pin before continuing.");
      return;
    }

    setIsSaving(true);
    setError(null);

    try {
      const updated = await userSetupService.saveHostLocation(draft, parsed.data);
      setDraft(updated);
      navigation.replace("HostSpaceAddress", { draftId: updated.id });
    } catch (saveError) {
      setError(toAuthError(saveError).message);
    } finally {
      setIsSaving(false);
    }
  }, [coordinates, draft, navigation, preview, setDraft]);

  return (
    <SafeAreaView style={styles.screen}>
      <StatusBar backgroundColor="#FFFFFF" style="dark" translucent={false} />
      <View style={styles.header}>
        <Pressable accessibilityRole="button" hitSlop={10} style={styles.backButton} onPress={() => navigation.replace("UserSetupProfile", { intent: "host" })}>
          <Ionicons color="#0A0A0B" name="chevron-back" size={22} />
        </Pressable>
        <Text style={styles.brand}>Urban Parking</Text>
        <View style={styles.backButtonPlaceholder} />
      </View>
      <View style={styles.progressTrack}>
        <View style={styles.progressFill} />
      </View>

      <View style={styles.mapStage}>
        <OpenStreetAddressPicker
          isBusy={isReverseGeocoding}
          isLocating={isLocating}
          latitude={coordinates?.latitude ?? null}
          longitude={coordinates?.longitude ?? null}
          mapShellStyle={styles.mapShell}
          showLocateButton={false}
          style={styles.mapPicker}
          onPinChanged={handlePinChanged}
          onPinConfirmed={handlePinChanged}
        />

        <Pressable
          accessibilityLabel="Use current location"
          accessibilityRole="button"
          disabled={isLocating}
          style={[styles.currentLocationChip, isLocating ? styles.currentLocationChipDisabled : null]}
          onPress={handleUseCurrentLocation}
        >
          {isLocating ? (
            <ActivityIndicator color="#0A0A0B" size="small" />
          ) : (
            <Ionicons color="#0A0A0B" name="locate" size={25} />
          )}
        </Pressable>

        <View style={styles.sheet}>
          <View style={styles.handle} />
          <Text style={styles.sheetHint}>Place the pin at exact parking location</Text>

          <View style={styles.previewRow}>
            <View style={styles.previewIcon}>
              <Ionicons color="#0A0A0B" name="location" size={20} />
            </View>
            <View style={styles.previewCopy}>
              <Text numberOfLines={1} style={styles.previewTitle}>
                {previewTitle}
              </Text>
              <Text numberOfLines={2} style={styles.previewSubtitle}>
                {isReverseGeocoding ? "Finding this area..." : previewSubtitle}
              </Text>
            </View>
          </View>

          {lookupError ? <Text style={styles.lookupError}>{lookupError}</Text> : null}
          {error ? <Text style={styles.lookupError}>{error}</Text> : null}

          <Button
            disabled={!draft || !hasCoordinate}
            label="Confirm & proceed"
            loading={isSaving}
            style={styles.confirmButton}
            onPress={handleConfirm}
          />
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: "#FFFFFF"
  },
  header: {
    minHeight: 58,
    paddingHorizontal: 18,
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between"
  },
  backButton: {
    width: 40,
    height: 40,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 20,
    backgroundColor: "#FFFFFF",
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.08)"
  },
  backButtonPlaceholder: {
    width: 40,
    height: 40
  },
  brand: {
    color: "#0A0A0B",
    fontSize: 18,
    fontWeight: "900"
  },
  progressTrack: {
    height: 4,
    marginHorizontal: 20,
    borderRadius: 999,
    backgroundColor: "#E7E7E7",
    overflow: "hidden"
  },
  progressFill: {
    width: "48%",
    height: 4,
    borderRadius: 999,
    backgroundColor: "#0A0A0B"
  },
  mapStage: {
    flex: 1,
    marginTop: 8,
    overflow: "hidden",
    backgroundColor: "#EEF0F4"
  },
  mapPicker: {
    flex: 1,
    gap: 0
  },
  mapShell: {
    flex: 1,
    height: "100%"
  },
  currentLocationChip: {
    position: "absolute",
    right: 26,
    bottom: 276,
    width: 54,
    height: 54,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 27,
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.08)",
    backgroundColor: "#FFFFFF",
    shadowColor: "#000000",
    shadowOpacity: 0.16,
    shadowRadius: 16,
    shadowOffset: { height: 8, width: 0 },
    elevation: 10,
    zIndex: 20
  },
  currentLocationChipDisabled: {
    opacity: 0.7
  },
  sheet: {
    position: "absolute",
    left: 18,
    right: 18,
    bottom: 18,
    gap: 12,
    paddingHorizontal: 18,
    paddingTop: 12,
    paddingBottom: 16,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.06)",
    backgroundColor: "#FFFFFF",
    shadowColor: "#000000",
    shadowOpacity: 0.16,
    shadowRadius: 24,
    shadowOffset: { height: 12, width: 0 },
    elevation: 12
  },
  handle: {
    width: 46,
    height: 5,
    alignSelf: "center",
    borderRadius: 999,
    backgroundColor: "#D7D7D7"
  },
  sheetHint: {
    color: "#6A6A6F",
    fontSize: 13,
    fontWeight: "900",
    lineHeight: 18
  },
  previewRow: {
    alignItems: "center",
    flexDirection: "row",
    gap: 11
  },
  previewIcon: {
    width: 34,
    height: 34,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 17,
    backgroundColor: "rgba(10,10,11,0.08)"
  },
  previewCopy: {
    flex: 1,
    gap: 3
  },
  previewTitle: {
    color: "#0A0A0B",
    fontSize: 18,
    fontWeight: "900",
    lineHeight: 23
  },
  previewSubtitle: {
    color: "#5E5E63",
    fontSize: 13,
    fontWeight: "700",
    lineHeight: 18
  },
  lookupError: {
    color: "#B42318",
    fontSize: 12,
    fontWeight: "800",
    lineHeight: 18
  },
  confirmButton: {
    height: 58,
    borderRadius: 14
  }
});
