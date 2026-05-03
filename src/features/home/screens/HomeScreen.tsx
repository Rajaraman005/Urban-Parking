import type { BottomTabNavigationProp } from "@react-navigation/bottom-tabs";
import { useNavigation } from "@react-navigation/native";
import { useMemo } from "react";
import { ScrollView, View } from "react-native";

import { TopNavBar } from "@/components/navigation/TopNavBar";
import { HeroCarousel, type HeroSlide } from "@/components/ui/HeroCarousel";
import { Screen } from "@/components/ui/Screen";
import type { MainTabParamList } from "@/core/navigation/types";
import { HomeDiscoveryActions, type HomeDiscoveryAction } from "@/features/home/components/HomeDiscoveryActions";
import { HOME_DISCOVERY_ACTION_ITEMS } from "@/features/home/data/homeDiscoveryActionItems";
import { useAppTheme } from "@/theme/useAppTheme";

type HomeNavigation = BottomTabNavigationProp<MainTabParamList, "Home">;

export function HomeScreen() {
  const navigation = useNavigation<HomeNavigation>();
  const { colors } = useAppTheme();

  const heroSlides: HeroSlide[] = useMemo(
    () => [
      {
        id: "slide-rentals",
        image: require("../../../assets/home/carosel_img_1.jpg"),
        tag: "RENTALS",
        title: "Rent Cars & Bikes",
        subtitle: "Premium vehicles at your doorstep - daily, weekly, or monthly plans",
        onPress: () => navigation.navigate("Search"),
      },
      {
        id: "slide-services",
        image: require("../../../assets/home/carosel_img_2.jpg"),
        tag: "SERVICES",
        title: "Expert Repairs",
        subtitle: "Car & bike servicing by certified mechanics - at your location",
        onPress: () => navigation.navigate("Search"),
      },
      {
        id: "slide-parking",
        image: require("../../../assets/home/carosel_img_3.jpg"),
        tag: "PARKING",
        title: "Smart Parking",
        subtitle: "Find & book secure parking spots instantly - covered & open options",
        onPress: () => navigation.navigate("Search"),
      },
    ],
    [navigation],
  );

  const discoveryActions: HomeDiscoveryAction[] = useMemo(
    () =>
      HOME_DISCOVERY_ACTION_ITEMS.map((item) => ({
        accessibilityLabel: item.accessibilityLabel,
        icon: item.icon,
        id: item.id,
        label: item.label,
        onPress: () => navigation.navigate(item.route),
      })),
    [navigation],
  );

  return (
    <Screen padded={false}>
      <View style={{ flex: 1, backgroundColor: colors.background }}>
        <TopNavBar title="Urban Parking" />
        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: 32 }}
        >
          <HeroCarousel
            slides={heroSlides}
            sectionTitle={null}
            sectionAction={null}
          />
          <HomeDiscoveryActions actions={discoveryActions} />
        </ScrollView>
      </View>
    </Screen>
  );
}
