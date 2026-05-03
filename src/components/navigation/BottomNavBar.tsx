import { Ionicons } from "@expo/vector-icons";
import type { BottomTabBarProps } from "@react-navigation/bottom-tabs";
import { type ComponentProps, useEffect, useMemo, useRef } from "react";
import { Image, Pressable, StyleSheet, Text, View, useWindowDimensions } from "react-native";
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from "react-native-reanimated";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import type { MainTabParamList } from "@/core/navigation/types";
import { useAuthStore } from "@/features/auth/store/authStore";
import { useAppTheme } from "@/theme/useAppTheme";

type IconName = ComponentProps<typeof Ionicons>["name"];

const ACTIVE_COLOR = "#050505";
const ACTIVE_BUBBLE_SIZE = 44;
const PROFILE_TOKEN_SIZE = 26;
const ICON_SIZE = 24;
const BAR_HORIZONTAL_PADDING = 10;
const BAR_TOP_PADDING = 7;

interface BottomNavItemConfig {
  activeIcon: IconName;
  inactiveIcon: IconName;
  label: string;
  route: keyof MainTabParamList;
  type?: "avatar" | "icon";
}

const NAV_ITEMS: BottomNavItemConfig[] = [
  { route: "Home", label: "Home", activeIcon: "home-outline", inactiveIcon: "home-outline" },
  { route: "Rental", label: "Rent", activeIcon: "car-sport-outline", inactiveIcon: "car-sport-outline" },
  { route: "Search", label: "Search", activeIcon: "search-outline", inactiveIcon: "search-outline" },
  { route: "Services", label: "Services", activeIcon: "sparkles-outline", inactiveIcon: "sparkles-outline" },
  { route: "Profile", label: "Profile", activeIcon: "person-outline", inactiveIcon: "person-outline", type: "avatar" },
];

function getProfileMonogram(fullName: string | null | undefined, email: string | null | undefined) {
  if (fullName && fullName.trim().length > 0) {
    const parts = fullName.trim().split(/\s+/);
    const first = parts[0]?.[0] ?? "";
    const second = parts[1]?.[0] ?? "";

    if (first && second) {
      return `${first.toUpperCase()}${second.toLowerCase()}`;
    }

    const trimmed = fullName.trim().slice(0, 2);
    const firstChar = trimmed[0]?.toUpperCase() ?? "P";
    const secondChar = trimmed[1]?.toLowerCase() ?? "";
    return `${firstChar}${secondChar}`;
  }

  if (email) {
    const local = email.split("@")[0] ?? "";
    const firstChar = local[0]?.toUpperCase() ?? "P";
    const secondChar = local[1]?.toLowerCase() ?? "";
    return `${firstChar}${secondChar}`;
  }

  return "Pr";
}

interface TabSlotProps {
  accessibilityLabel: string;
  avatarUrl: string | null;
  isFocused: boolean;
  label: string;
  monogram: string;
  onLongPress: () => void;
  onPress: () => void;
  testID?: string;
  type?: "avatar" | "icon";
  inactiveIcon: IconName;
}

function TabSlot({
  accessibilityLabel,
  avatarUrl,
  isFocused,
  label,
  monogram,
  onLongPress,
  onPress,
  testID,
  type = "icon",
  inactiveIcon,
}: TabSlotProps) {
  return (
    <Pressable
      accessibilityLabel={accessibilityLabel}
      accessibilityRole="button"
      accessibilityState={isFocused ? { selected: true } : {}}
      hitSlop={10}
      style={styles.slot}
      testID={testID}
      onLongPress={onLongPress}
      onPress={onPress}
    >
      <View style={styles.visualWrap}>
        {isFocused ? (
          <View style={styles.focusedSpacer} />
        ) : type === "avatar" ? (
          <View
            style={[
              styles.avatarToken,
              {
                width: PROFILE_TOKEN_SIZE,
                height: PROFILE_TOKEN_SIZE,
                borderRadius: PROFILE_TOKEN_SIZE / 2,
              },
            ]}
          >
            {avatarUrl ? (
              <Image
                source={{ uri: avatarUrl }}
                style={[
                  styles.profileImage,
                  {
                    width: PROFILE_TOKEN_SIZE,
                    height: PROFILE_TOKEN_SIZE,
                    borderRadius: PROFILE_TOKEN_SIZE / 2,
                  },
                ]}
              />
            ) : (
              <Text style={styles.avatarTokenText}>{monogram}</Text>
            )}
          </View>
        ) : (
          <Ionicons color="#0A0A0B" name={inactiveIcon} size={ICON_SIZE} />
        )}
      </View>

      {!isFocused ? <Text style={styles.tabLabel}>{label}</Text> : null}
    </Pressable>
  );
}

export function BottomNavBar({ descriptors, navigation, state }: BottomTabBarProps) {
  const { colors } = useAppTheme();
  const insets = useSafeAreaInsets();
  const { width } = useWindowDimensions();
  const profile = useAuthStore((store) => store.profile);
  const user = useAuthStore((store) => store.user);
  const profileMonogram = getProfileMonogram(profile?.full_name, user?.email);
  const profileAvatarUrl = profile?.avatar_url ?? null;
  const routesByName = new Map(state.routes.map((route) => [route.name, route]));
  const activeIndex = state.index;
  const activeItem = NAV_ITEMS[activeIndex] ?? NAV_ITEMS[0]!;
  const previousIndex = useRef(activeIndex);
  const slotWidth = useMemo(
    () => (width - BAR_HORIZONTAL_PADDING * 2) / NAV_ITEMS.length,
    [width],
  );
  const bubbleOffsetX = BAR_HORIZONTAL_PADDING + (slotWidth - ACTIVE_BUBBLE_SIZE) / 2;

  const translateX = useSharedValue(bubbleOffsetX + slotWidth * activeIndex);
  const rotation = useSharedValue(0);

  useEffect(() => {
    translateX.value = withTiming(bubbleOffsetX + slotWidth * activeIndex, {
      duration: 320,
      easing: Easing.out(Easing.cubic),
    });

    const direction = activeIndex >= previousIndex.current ? 1 : -1;
    rotation.value = withTiming(rotation.value + direction * 1.1, {
      duration: 320,
      easing: Easing.out(Easing.cubic),
    });

    previousIndex.current = activeIndex;
  }, [activeIndex, bubbleOffsetX, rotation, slotWidth, translateX]);

  const animatedBubbleStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: -12 },
      { rotateZ: `${rotation.value * 180}deg` },
    ],
  }));

  const animatedBubbleContentStyle = useAnimatedStyle(() => ({
    transform: [{ rotateZ: `${rotation.value * -180}deg` }],
  }));

  return (
    <View
      style={[
        styles.outerShell,
        {
          paddingBottom: Math.max(insets.bottom, 9),
        },
      ]}
    >
      <View
        style={[
          styles.innerShell,
          {
            backgroundColor: colors.surface,
            paddingHorizontal: BAR_HORIZONTAL_PADDING,
            paddingTop: BAR_TOP_PADDING,
            paddingBottom: 6,
          },
        ]}
      >
        <Animated.View
          pointerEvents="none"
          style={[
            styles.activeBubble,
            animatedBubbleStyle,
            {
              width: ACTIVE_BUBBLE_SIZE,
              height: ACTIVE_BUBBLE_SIZE,
              borderRadius: ACTIVE_BUBBLE_SIZE / 2,
              top: BAR_TOP_PADDING,
            },
          ]}
        >
          <Animated.View style={[styles.activeBubbleContent, animatedBubbleContentStyle]}>
            {activeItem.type === "avatar" ? (
              profileAvatarUrl ? (
                <Image
                  source={{ uri: profileAvatarUrl }}
                  style={[
                    styles.profileImage,
                    {
                      width: ACTIVE_BUBBLE_SIZE,
                      height: ACTIVE_BUBBLE_SIZE,
                      borderRadius: ACTIVE_BUBBLE_SIZE / 2,
                    },
                  ]}
                />
              ) : (
                <Text style={styles.activeAvatarText}>{profileMonogram}</Text>
              )
            ) : (
              <Ionicons color="#FFFFFF" name={activeItem.activeIcon} size={ICON_SIZE} />
            )}
          </Animated.View>
        </Animated.View>

        <View style={styles.row}>
          {NAV_ITEMS.map((item) => {
            const route = routesByName.get(item.route);

            if (!route) {
              return null;
            }

            const routeIndex = state.routes.findIndex((entry) => entry.key === route.key);
            const isFocused = state.index === routeIndex;
            const descriptor = descriptors[route.key];

            if (!descriptor) {
              return null;
            }

            const onPress = () => {
              const event = navigation.emit({
                type: "tabPress",
                target: route.key,
                canPreventDefault: true,
              });

              if (!isFocused && !event.defaultPrevented) {
                navigation.navigate(route.name as never);
              }
            };

            const onLongPress = () => {
              navigation.emit({
                type: "tabLongPress",
                target: route.key,
              });
            };

            return (
              <TabSlot
                key={route.key}
                accessibilityLabel={descriptor.options.tabBarAccessibilityLabel ?? String(item.route)}
                avatarUrl={profileAvatarUrl}
                inactiveIcon={item.inactiveIcon}
                isFocused={isFocused}
                label={item.label}
                monogram={profileMonogram}
                testID={descriptor.options.tabBarTestID}
                type={item.type}
                onLongPress={onLongPress}
                onPress={onPress}
              />
            );
          })}
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  outerShell: {
    backgroundColor: "transparent",
  },
  innerShell: {
    borderRadius: 0,
    position: "relative",
  },
  row: {
    flexDirection: "row",
    alignItems: "flex-start",
    justifyContent: "space-between",
  },
  slot: {
    flex: 1,
    minHeight: 44,
    alignItems: "center",
    justifyContent: "flex-start",
    gap: 0,
  },
  visualWrap: {
    height: 31,
    alignItems: "center",
    justifyContent: "center",
  },
  focusedSpacer: {
    width: ACTIVE_BUBBLE_SIZE,
    height: 31,
  },
  activeBubble: {
    position: "absolute",
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: ACTIVE_COLOR,
    shadowColor: "#0A0A0B",
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.14,
    shadowRadius: 12,
    elevation: 10,
    zIndex: 4,
  },
  activeBubbleContent: {
    width: "100%",
    height: "100%",
    alignItems: "center",
    justifyContent: "center",
  },
  avatarToken: {
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#0A0A0B",
    overflow: "hidden",
  },
  avatarTokenText: {
    color: "#FFFFFF",
    fontSize: 12,
    fontWeight: "800",
  },
  activeAvatarText: {
    color: "#FFFFFF",
    fontSize: 16,
    fontWeight: "800",
  },
  profileImage: {
    overflow: "hidden",
  },
  tabLabel: {
    color: "#0A0A0B",
    fontSize: 9,
    lineHeight: 10,
    fontWeight: "600",
    textAlign: "center",
    marginTop: 1,
  },
});
