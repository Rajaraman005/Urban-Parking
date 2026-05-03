import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { useEffect, useState } from "react";
import { Image, StyleSheet, Text, View } from "react-native";

import type { RootStackParamList } from "@/core/navigation/types";
import { toAuthError } from "@/features/auth/services/authErrors";
import { useAuthStore } from "@/features/auth/store/authStore";
import { SetupScaffold } from "@/features/userSetup/components/SetupScaffold";
import { userSetupService } from "@/features/userSetup/services/userSetupService";
import { useUserSetupStore } from "@/features/userSetup/store/userSetupStore";
import type { ParkingSpace, ParkingSpacePhoto } from "@/features/userSetup/types/userSetup.types";

type Props = NativeStackScreenProps<RootStackParamList, "HostSpaceReview">;

const formatValue = (value: string | number | null | undefined, fallback = "Not set") =>
  value === null || value === undefined || value === "" ? fallback : String(value);

export function HostSpaceReviewScreen({ navigation, route }: Props) {
  const refreshSessionOrLogout = useAuthStore((state) => state.refreshSessionOrLogout);
  const setDraft = useUserSetupStore((state) => state.setDraft);
  const setStorePhotos = useUserSetupStore((state) => state.setPhotos);
  const [draft, setLocalDraft] = useState<ParkingSpace | null>(null);
  const [photos, setPhotos] = useState<ParkingSpacePhoto[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    let isMounted = true;

    const load = async () => {
      try {
        const snapshot = await userSetupService.loadDraftWithPhotos(route.params.draftId);

        if (!isMounted) {
          return;
        }

        setDraft(snapshot.draft);
        setLocalDraft(snapshot.draft);
        setPhotos(snapshot.photos);
        setStorePhotos(snapshot.photos);
      } catch (loadError) {
        setError(toAuthError(loadError).message);
      }
    };

    void load();

    return () => {
      isMounted = false;
    };
  }, [route.params.draftId, setDraft, setStorePhotos]);

  const submit = async () => {
    if (!draft) {
      return;
    }

    setError(null);
    setIsSubmitting(true);

    try {
      await userSetupService.submitForReview(draft);
      await refreshSessionOrLogout();
      navigation.replace("MainTabs", { screen: "Home" });
    } catch (submitError) {
      setError(toAuthError(submitError).message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <SetupScaffold
      description="No space goes live instantly. We submit it for review so the marketplace stays safe and high quality."
      error={error}
      primaryDisabled={!draft || photos.length < 2}
      primaryLabel="Submit for review"
      primaryLoading={isSubmitting}
      progress={1}
      title="Review your listing"
      onBack={() => navigation.replace("HostSpacePhotos", { draftId: route.params.draftId })}
      onPrimaryPress={submit}
    >
      {photos[0] ? <Image source={{ uri: photos[0].secure_url }} style={styles.heroImage} /> : null}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>{draft?.title ?? "Parking space"}</Text>
        <Text style={styles.line}>{formatValue(draft?.address)}</Text>
        <Text style={styles.line}>
          {[draft?.locality, draft?.city, draft?.postal_code].filter(Boolean).join(", ") || "Not set"}
        </Text>
      </View>
      <View style={styles.card}>
        <ReviewRow label="Vehicle fit" value={formatValue(draft?.vehicle_fit)} />
        <ReviewRow label="Parking type" value={formatValue(draft?.parking_type)} />
        <ReviewRow label="Slots" value={formatValue(draft?.slots_count)} />
        <ReviewRow label="Hourly price" value={`Rs ${formatValue(draft?.hourly_price, "0")}`} />
        <ReviewRow
          label="Size"
          value={`${formatValue(draft?.length_feet, "-")} x ${formatValue(draft?.width_feet, "-")} ft`}
        />
        <ReviewRow label="Availability" value={formatValue(draft?.availability_summary)} />
      </View>
      <View style={styles.notice}>
        <Text style={styles.noticeTitle}>Submitted listings enter pending review</Text>
        <Text style={styles.noticeBody}>Admin approval is required before renters can discover or book this space.</Text>
      </View>
    </SetupScaffold>
  );
}

function ReviewRow({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.row}>
      <Text style={styles.rowLabel}>{label}</Text>
      <Text style={styles.rowValue}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  heroImage: {
    width: "100%",
    aspectRatio: 1.5,
    borderRadius: 22,
    backgroundColor: "#EEEEEE"
  },
  card: {
    gap: 10,
    padding: 18,
    borderRadius: 22,
    backgroundColor: "#FFFFFF",
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.08)"
  },
  cardTitle: {
    color: "#0A0A0B",
    fontSize: 21,
    fontWeight: "900"
  },
  line: {
    color: "#666666",
    fontSize: 14,
    fontWeight: "800",
    lineHeight: 20
  },
  row: {
    gap: 4,
    paddingVertical: 4
  },
  rowLabel: {
    color: "#777777",
    fontSize: 12,
    fontWeight: "900",
    textTransform: "uppercase"
  },
  rowValue: {
    color: "#0A0A0B",
    fontSize: 15,
    fontWeight: "900",
    lineHeight: 21
  },
  notice: {
    gap: 6,
    padding: 16,
    borderRadius: 18,
    backgroundColor: "#0A0A0B"
  },
  noticeTitle: {
    color: "#FFFFFF",
    fontSize: 15,
    fontWeight: "900"
  },
  noticeBody: {
    color: "rgba(255,255,255,0.72)",
    fontSize: 13,
    fontWeight: "700",
    lineHeight: 18
  }
});
