import { useNavigation } from "@react-navigation/native";
import type { NativeStackNavigationProp } from "@react-navigation/native-stack";
import { useCallback, useMemo } from "react";
import { FlatList, Pressable, Text, View } from "react-native";
import MapView, { Marker, PROVIDER_GOOGLE } from "react-native-maps";

import type { RootStackParamList } from "@/core/navigation/types";
import { Button } from "@/components/ui/Button";
import { Screen } from "@/components/ui/Screen";
import { Skeleton } from "@/components/ui/Skeleton";
import { CHENNAI_CENTER } from "@/constants/mockParking";
import { ParkingSpotCard } from "@/features/home/components/ParkingSpotCard";
import { useNearbyParking } from "@/features/home/hooks/useNearbyParking";
import type { ParkingSpot } from "@/models/parking";
import { useParkingStore } from "@/store/parkingStore";
import { useAppTheme } from "@/theme/useAppTheme";
import { formatMoney } from "@/utils/format";

type RootNavigation = NativeStackNavigationProp<RootStackParamList>;

export function HomeScreen() {
  const navigation = useNavigation<RootNavigation>();
  const { colors } = useAppTheme();
  const { spots, center, isLoading, error, refresh } = useNearbyParking();
  const selectSpot = useParkingStore((state) => state.selectSpot);

  const region = useMemo(
    () => ({
      latitude: center.latitude,
      longitude: center.longitude,
      latitudeDelta: CHENNAI_CENTER.latitudeDelta,
      longitudeDelta: CHENNAI_CENTER.longitudeDelta
    }),
    [center.latitude, center.longitude]
  );

  const openBooking = useCallback(
    (spot: ParkingSpot) => {
      selectSpot(spot.id);
      navigation.navigate("Booking", { spotId: spot.id });
    },
    [navigation, selectSpot]
  );

  return (
    <Screen padded={false}>
      <View style={{ flex: 1 }}>
        <MapView provider={PROVIDER_GOOGLE} style={{ flex: 1 }} initialRegion={region} showsUserLocation>
          {spots.map((spot) => (
            <Marker key={spot.id} coordinate={spot.location} title={spot.title} description={spot.address}>
              <Pressable
                style={{
                  minWidth: 82,
                  minHeight: 36,
                  borderRadius: 18,
                  backgroundColor: colors.text,
                  alignItems: "center",
                  justifyContent: "center",
                  paddingHorizontal: 12,
                  borderWidth: 2,
                  borderColor: colors.surface
                }}
              >
                <Text style={{ color: colors.background, fontWeight: "800", fontSize: 13 }}>
                  {formatMoney(spot.price, spot.currency)}
                </Text>
              </Pressable>
            </Marker>
          ))}
        </MapView>
        <View
          style={{
            position: "absolute",
            top: 18,
            left: 20,
            right: 20,
            borderRadius: 8,
            backgroundColor: colors.surface,
            borderWidth: 1,
            borderColor: colors.border,
            padding: 14,
            gap: 4
          }}
        >
          <Text style={{ color: colors.text, fontSize: 18, fontWeight: "800" }}>Parking near you</Text>
          <Text style={{ color: colors.muted, fontSize: 13 }}>Live slots around Chennai</Text>
        </View>
        <View
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            bottom: 18,
            gap: 12
          }}
        >
          {error ? (
            <View style={{ marginHorizontal: 20, padding: 14, borderRadius: 8, backgroundColor: colors.surface }}>
              <Text style={{ color: colors.danger, marginBottom: 10 }}>{error}</Text>
              <Button label="Retry" variant="secondary" onPress={refresh} />
            </View>
          ) : null}
          {isLoading ? (
            <View style={{ marginHorizontal: 20, gap: 10, padding: 14, borderRadius: 8, backgroundColor: colors.surface }}>
              <Skeleton height={128} />
              <Skeleton width="70%" height={18} />
              <Skeleton width="48%" height={14} />
            </View>
          ) : (
            <FlatList
              horizontal
              data={spots}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => <ParkingSpotCard spot={item} onPress={openBooking} />}
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={{ paddingHorizontal: 20, gap: 12 }}
              initialNumToRender={3}
              maxToRenderPerBatch={4}
              windowSize={5}
            />
          )}
        </View>
      </View>
    </Screen>
  );
}
