import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { useEffect, useMemo, useState } from "react";
import { Image, ScrollView, Text, View } from "react-native";

import type { RootStackParamList } from "@/core/navigation/types";
import { Button } from "@/components/ui/Button";
import { Loader } from "@/components/ui/Loader";
import { Screen } from "@/components/ui/Screen";
import type { BookingQuote, ParkingSpot } from "@/models/parking";
import { parkingApi } from "@/services/api/parkingApi";
import { toApiError } from "@/services/api/apiClient";
import { useAppTheme } from "@/theme/useAppTheme";
import { cadenceLabel, formatMoney } from "@/utils/format";

type Props = NativeStackScreenProps<RootStackParamList, "Booking">;

export function BookingScreen({ navigation, route }: Props) {
  const { colors } = useAppTheme();
  const [spot, setSpot] = useState<ParkingSpot | null>(null);
  const [quote, setQuote] = useState<BookingQuote | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const bookingWindow = useMemo(
    () => ({
      startAt: "2026-04-27T18:00:00+05:30",
      endAt: "2026-04-27T21:00:00+05:30"
    }),
    []
  );

  useEffect(() => {
    async function loadBooking() {
      try {
        const [nextSpot, nextQuote] = await Promise.all([
          parkingApi.getById(route.params.spotId),
          parkingApi.quoteBooking(route.params.spotId, bookingWindow.startAt, bookingWindow.endAt)
        ]);
        setSpot(nextSpot);
        setQuote(nextQuote);
      } catch (loadError) {
        setError(toApiError(loadError).message);
      } finally {
        setIsLoading(false);
      }
    }

    void loadBooking();
  }, [bookingWindow.endAt, bookingWindow.startAt, route.params.spotId]);

  if (isLoading) {
    return (
      <Screen>
        <Loader />
      </Screen>
    );
  }

  if (!spot || !quote) {
    return (
      <Screen>
        <View style={{ flex: 1, justifyContent: "center", gap: 16 }}>
          <Text style={{ color: colors.text, fontSize: 22, fontWeight: "800" }}>Could not load booking</Text>
          <Text style={{ color: colors.muted }}>{error}</Text>
          <Button label="Back to map" onPress={() => navigation.goBack()} />
        </View>
      </Screen>
    );
  }

  return (
    <Screen>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ gap: 18, paddingBottom: 28 }}>
        <Button label="Back" variant="ghost" onPress={() => navigation.goBack()} />
        <Image source={{ uri: `${spot.imageUrl}?auto=format&fit=crop&w=1000&q=80` }} style={{ height: 220, borderRadius: 8 }} />
        <View style={{ gap: 8 }}>
          <Text style={{ color: colors.text, fontSize: 30, lineHeight: 36, fontWeight: "800" }}>{spot.title}</Text>
          <Text style={{ color: colors.muted, fontSize: 15 }}>{spot.address}</Text>
        </View>
        <View style={{ flexDirection: "row", gap: 10 }}>
          {spot.amenities.slice(0, 3).map((amenity) => (
            <View key={amenity} style={{ borderRadius: 8, backgroundColor: colors.surface, paddingHorizontal: 12, paddingVertical: 10 }}>
              <Text style={{ color: colors.text, fontSize: 13, fontWeight: "700" }}>{amenity}</Text>
            </View>
          ))}
        </View>
        <View style={{ borderRadius: 8, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, padding: 16, gap: 14 }}>
          <Text style={{ color: colors.text, fontSize: 18, fontWeight: "800" }}>Booking summary</Text>
          <Text style={{ color: colors.muted }}>Today, 6:00 PM to 9:00 PM</Text>
          <Row label={`${formatMoney(spot.price, spot.currency)} / ${cadenceLabel(spot.cadence)}`} value={formatMoney(quote.subtotal)} />
          <Row label="Platform fee" value={formatMoney(quote.platformFee)} />
          <Row label="GST" value={formatMoney(quote.taxes)} />
          <View style={{ height: 1, backgroundColor: colors.border }} />
          <Row label="Total" value={formatMoney(quote.total)} strong />
        </View>
        <Button label="Reserve slot" onPress={() => navigation.navigate("MainTabs", { screen: "Home" })} />
      </ScrollView>
    </Screen>
  );
}

function Row({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  const { colors } = useAppTheme();

  return (
    <View style={{ flexDirection: "row", justifyContent: "space-between", gap: 16 }}>
      <Text style={{ color: strong ? colors.text : colors.muted, fontSize: 15, fontWeight: strong ? "800" : "500" }}>
        {label}
      </Text>
      <Text style={{ color: colors.text, fontSize: 15, fontWeight: "800" }}>{value}</Text>
    </View>
  );
}
