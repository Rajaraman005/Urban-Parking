import { memo, useCallback } from "react";
import {
  FlatList,
  type ListRenderItem,
  Pressable,
  StyleSheet,
  Text,
  View
} from "react-native";

import { DiscoveryStateView } from "@/shared/components/DiscoveryStateView";
import { useAppTheme } from "@/theme/useAppTheme";
import type { GeoDiscoveryEntity, GeoDiscoveryPartialFailure } from "@/types/geo";

interface GeoListViewProps<TEntity> {
  error?: string | null;
  isLoading?: boolean;
  isPaginating?: boolean;
  isStale?: boolean;
  items: GeoDiscoveryEntity<TEntity>[];
  onEndReached?: () => void;
  onRetry?: () => void;
  partialFailures?: GeoDiscoveryPartialFailure[];
  permissionDenied?: boolean;
  renderItem?: ListRenderItem<GeoDiscoveryEntity<TEntity>>;
}

function DefaultGeoListRow<TEntity>({ item }: { item: GeoDiscoveryEntity<TEntity> }) {
  const { colors } = useAppTheme();

  return (
    <View
      accessibilityLabel={`${item.title}, ${item.distanceKm.toFixed(1)} kilometers away, ${item.availabilityStatus}`}
      accessibilityRole="button"
      style={[styles.row, { borderBottomColor: colors.border }]}
    >
      <View style={styles.rowText}>
        <Text numberOfLines={1} style={[styles.title, { color: colors.text }]}>
          {item.title}
        </Text>
        <Text style={[styles.meta, { color: colors.muted }]}>
          {item.distanceKm.toFixed(1)} km - {item.availabilityStatus}
        </Text>
      </View>
      {typeof item.price === "number" ? (
        <Text style={[styles.price, { color: colors.text }]}>INR {item.price}</Text>
      ) : null}
    </View>
  );
}

function GeoListViewBase<TEntity>({
  error,
  isLoading = false,
  isPaginating = false,
  isStale = false,
  items,
  onEndReached,
  onRetry,
  partialFailures = [],
  permissionDenied = false,
  renderItem
}: GeoListViewProps<TEntity>) {
  const { colors } = useAppTheme();
  const defaultRenderItem = useCallback<ListRenderItem<GeoDiscoveryEntity<TEntity>>>(
    ({ item }) => <DefaultGeoListRow item={item} />,
    [],
  );

  if (permissionDenied) {
    return (
      <DiscoveryStateView
        actionLabel="Try again"
        body="Enable location access to discover resources near you."
        onAction={onRetry}
        title="Location permission needed"
      />
    );
  }

  if (isLoading && items.length === 0) {
    return <DiscoveryStateView body="Finding nearby resources around you." isLoading title="Searching nearby" />;
  }

  if (error && items.length === 0) {
    return <DiscoveryStateView body={error} onAction={onRetry} title="Unable to load results" />;
  }

  if (items.length === 0) {
    return (
      <DiscoveryStateView
        body="Try increasing the radius or changing filters."
        onAction={onRetry}
        title="No nearby results"
      />
    );
  }

  return (
    <View style={styles.container}>
      {isStale ? (
        <Text style={[styles.banner, { color: colors.muted }]}>Showing cached nearby results.</Text>
      ) : null}
      {partialFailures.length > 0 ? (
        <Text style={[styles.banner, { color: colors.danger }]}>
          Some categories could not refresh. Pull to retry.
        </Text>
      ) : null}
      <FlatList
        data={items}
        keyExtractor={(item) => `${item.serviceType}:${item.id}`}
        onEndReached={onEndReached}
        onEndReachedThreshold={0.6}
        renderItem={renderItem ?? defaultRenderItem}
        ListFooterComponent={
          isPaginating ? (
            <Pressable accessibilityRole="button" disabled style={styles.footerLoading}>
              <Text style={[styles.meta, { color: colors.muted }]}>Loading more...</Text>
            </Pressable>
          ) : null
        }
      />
    </View>
  );
}

export const GeoListView = memo(GeoListViewBase) as typeof GeoListViewBase;

const styles = StyleSheet.create({
  banner: {
    fontSize: 12,
    fontWeight: "700",
    paddingHorizontal: 16,
    paddingVertical: 8
  },
  container: {
    flex: 1
  },
  footerLoading: {
    alignItems: "center",
    justifyContent: "center",
    minHeight: 44
  },
  meta: {
    fontSize: 12,
    fontWeight: "600",
    lineHeight: 17
  },
  price: {
    fontSize: 15,
    fontWeight: "900"
  },
  row: {
    alignItems: "center",
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: "row",
    justifyContent: "space-between",
    minHeight: 64,
    paddingHorizontal: 16,
    paddingVertical: 10
  },
  rowText: {
    flex: 1,
    paddingRight: 12
  },
  title: {
    fontSize: 15,
    fontWeight: "900",
    lineHeight: 20
  }
});
