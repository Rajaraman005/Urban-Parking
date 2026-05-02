import { memo } from "react";
import { Image, Pressable, Text, View } from "react-native";

import type { ParkingSpot } from "@/models/parking";
import { useAppTheme } from "@/theme/useAppTheme";
import { cadenceLabel, formatMoney } from "@/utils/format";

interface ParkingSpotCardProps {
  spot: ParkingSpot;
  onPress: (spot: ParkingSpot) => void;
}

function ParkingSpotCardBase({ spot, onPress }: ParkingSpotCardProps) {
  const { colors } = useAppTheme();

  return (
    <Pressable
      onPress={() => onPress(spot)}
      style={({ pressed }) => ({
        width: 284,
        borderRadius: 8,
        backgroundColor: colors.surface,
        borderWidth: 1,
        borderColor: colors.border,
        overflow: "hidden",
        opacity: pressed ? 0.86 : 1
      })}
    >
      <Image source={{ uri: `${spot.imageUrl}?auto=format&fit=crop&w=800&q=80` }} style={{ height: 128 }} />
      <View style={{ padding: 14, gap: 8 }}>
        <View style={{ flexDirection: "row", justifyContent: "space-between", gap: 12 }}>
          <Text numberOfLines={1} style={{ color: colors.text, flex: 1, fontSize: 16, fontWeight: "700" }}>
            {spot.title}
          </Text>
          <Text style={{ color: colors.text, fontSize: 13, fontWeight: "700" }}>{spot.rating.toFixed(2)}</Text>
        </View>
        <Text numberOfLines={1} style={{ color: colors.muted, fontSize: 13 }}>
          {spot.locality} • {spot.distanceKm.toFixed(1)} km away
        </Text>
        <Text style={{ color: colors.text, fontSize: 15, fontWeight: "700" }}>
          {formatMoney(spot.price, spot.currency)} / {cadenceLabel(spot.cadence)}
        </Text>
      </View>
    </Pressable>
  );
}

export const ParkingSpotCard = memo(ParkingSpotCardBase);
