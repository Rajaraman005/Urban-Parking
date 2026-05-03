import { useMemo, useState } from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

import { GeoListView } from "@/features/geoDiscovery";
import { useGeoDiscoveryBatch } from "@/hooks/useGeoDiscoveryBatch";
import { Screen } from "@/components/ui/Screen";
import { useAppTheme } from "@/theme/useAppTheme";
import type { ServiceType } from "@/types/geo";

const serviceTabs: { label: string; value: ServiceType }[] = [
  { label: "Parking", value: "parking" },
  { label: "Rentals", value: "rental" },
  { label: "Services", value: "service" }
];

export function SearchScreen() {
  const { colors } = useAppTheme();
  const [selectedServiceType, setSelectedServiceType] = useState<ServiceType>("parking");
  const discovery = useGeoDiscoveryBatch();
  const selectedPage = discovery.result?.results[selectedServiceType];
  const selectedFailure = discovery.partialFailures.filter(
    (failure) => failure.serviceType === selectedServiceType,
  );
  const items = useMemo(() => selectedPage?.items ?? [], [selectedPage?.items]);

  return (
    <Screen padded={false}>
      <View style={[styles.container, { backgroundColor: colors.background }]}>
        <View style={styles.header}>
          <Text style={[styles.title, { color: colors.text }]}>Nearby</Text>
          <Text style={[styles.subtitle, { color: colors.muted }]}>Around you now</Text>
        </View>

        <View style={styles.tabs} accessibilityRole="tablist">
          {serviceTabs.map((tab) => {
            const active = selectedServiceType === tab.value;

            return (
              <Pressable
                accessibilityRole="tab"
                accessibilityState={{ selected: active }}
                key={tab.value}
                onPress={() => setSelectedServiceType(tab.value)}
                style={[
                  styles.tab,
                  {
                    backgroundColor: active ? colors.primary : colors.surface,
                    borderColor: colors.border
                  }
                ]}
              >
                <Text style={[styles.tabText, { color: active ? colors.primaryText : colors.text }]}>
                  {tab.label}
                </Text>
              </Pressable>
            );
          })}
        </View>

        <GeoListView
          error={discovery.error}
          isLoading={discovery.isLoading}
          isStale={Boolean(selectedPage?.isStale)}
          items={items}
          onRetry={discovery.refresh}
          partialFailures={selectedFailure}
          permissionDenied={discovery.permissionStatus === "denied" && !discovery.center}
        />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1
  },
  header: {
    gap: 4,
    paddingHorizontal: 20,
    paddingTop: 14,
    paddingBottom: 12
  },
  subtitle: {
    fontSize: 13,
    fontWeight: "600",
    lineHeight: 18
  },
  tab: {
    alignItems: "center",
    borderRadius: 999,
    borderWidth: 1,
    justifyContent: "center",
    minHeight: 44,
    paddingHorizontal: 16
  },
  tabText: {
    fontSize: 13,
    fontWeight: "900"
  },
  tabs: {
    flexDirection: "row",
    gap: 8,
    paddingHorizontal: 16,
    paddingBottom: 8
  },
  title: {
    fontSize: 24,
    fontWeight: "900",
    lineHeight: 30
  }
});
