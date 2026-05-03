import type { ComponentProps } from "react";
import type { Ionicons } from "@expo/vector-icons";

import type { MainTabParamList } from "@/core/navigation/types";

type IconName = ComponentProps<typeof Ionicons>["name"];

export interface HomeDiscoveryActionConfig {
  accessibilityLabel: string;
  icon: IconName;
  id: string;
  label: string;
  route: keyof MainTabParamList;
}

export const HOME_DISCOVERY_ACTION_ITEMS: readonly HomeDiscoveryActionConfig[] = [
  {
    accessibilityLabel: "Find bike rentals",
    icon: "bicycle-outline",
    id: "bike",
    label: "Bike",
    route: "Rental",
  },
  {
    accessibilityLabel: "Find car parking and rentals",
    icon: "car-sport-outline",
    id: "car",
    label: "Car",
    route: "Search",
  },
  {
    accessibilityLabel: "Open discovery filters",
    icon: "filter-outline",
    id: "filter",
    label: "Filter",
    route: "Search",
  },
];
