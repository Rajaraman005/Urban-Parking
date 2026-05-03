import { memo, useMemo } from "react";
import { StyleSheet, View } from "react-native";
import MapView, { Marker, type Region } from "react-native-maps";

import { geoDiscoveryConfig } from "@/config/geoDiscovery";
import { GeoListView } from "@/features/geoDiscovery/components/GeoListView";
import type { GeoDiscoveryEntity, GeoPoint } from "@/types/geo";

interface NearbyMapViewProps<TEntity> {
  center: GeoPoint | null;
  items: GeoDiscoveryEntity<TEntity>[];
  showList?: boolean;
}

function regionFor(center: GeoPoint | null, items: GeoDiscoveryEntity[]): Region {
  const fallback = center ?? items[0]?.location ?? { latitude: 13.0827, longitude: 80.2707 };

  return {
    latitude: fallback.latitude,
    latitudeDelta: 0.06,
    longitude: fallback.longitude,
    longitudeDelta: 0.06
  };
}

function NearbyMapViewBase<TEntity>({ center, items, showList = true }: NearbyMapViewProps<TEntity>) {
  const region = useMemo(() => regionFor(center, items), [center, items]);
  const visibleMarkers = useMemo(
    () => items.slice(0, geoDiscoveryConfig.performance.maxInitialMarkers),
    [items],
  );

  return (
    <View style={styles.container}>
      <MapView initialRegion={region} region={region} style={styles.map}>
        {visibleMarkers.map((item) => (
          <Marker
            coordinate={item.location}
            description={`${item.distanceKm.toFixed(1)} km away`}
            identifier={`${item.serviceType}:${item.id}`}
            key={`${item.serviceType}:${item.id}`}
            title={item.title}
          />
        ))}
      </MapView>
      {showList ? (
        <View style={styles.list}>
          <GeoListView items={items} />
        </View>
      ) : null}
    </View>
  );
}

export const NearbyMapView = memo(NearbyMapViewBase) as typeof NearbyMapViewBase;

const styles = StyleSheet.create({
  container: {
    flex: 1
  },
  list: {
    flex: 1
  },
  map: {
    flex: 1,
    minHeight: 240
  }
});
