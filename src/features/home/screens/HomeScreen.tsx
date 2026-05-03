import type { BottomTabNavigationProp } from "@react-navigation/bottom-tabs";
import { useNavigation } from "@react-navigation/native";
import { useMemo } from "react";
import { ScrollView, View } from "react-native";

import type { MainTabParamList } from "@/core/navigation/types";
import { TopNavBar } from "@/components/navigation/TopNavBar";
import { HeroCarousel, type HeroSlide } from "@/components/ui/HeroCarousel";
import { Screen } from "@/components/ui/Screen";
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
        subtitle:
          "Premium vehicles at your doorstep — daily, weekly, or monthly plans",
        onPress: () => navigation.navigate("Search"),
      },
      {
        id: "slide-services",
        image: require("../../../assets/home/carosel_img_2.jpg"),
        tag: "SERVICES",
        title: "Expert Repairs",
        subtitle:
          "Car & bike servicing by certified mechanics — at your location",
        onPress: () => navigation.navigate("Search"),
      },
      {
        id: "slide-parking",
        image: require("../../../assets/home/carosel_img_3.jpg"),
        tag: "PARKING",
        title: "Smart Parking",
        subtitle:
          "Find & book secure parking spots instantly — covered & open options",
        onPress: () => navigation.navigate("Search"),
      },
    ],
    [navigation],
  );

  return (
    <Screen padded={false}>
      <View style={{ flex: 1, backgroundColor: colors.background }}>
        <TopNavBar title="Urban Parking" />
        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{ paddingBottom: 24 }}
        >
          <HeroCarousel
            slides={heroSlides}
            sectionTitle={null}
            sectionAction={null}
          />
        </ScrollView>
      </View>
    </Screen>
  );
}
