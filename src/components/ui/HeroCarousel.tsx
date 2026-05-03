import { LinearGradient } from "expo-linear-gradient";
import { useCallback, useEffect, useRef } from "react";
import {
  type ImageSourcePropType,
  type NativeScrollEvent,
  type NativeSyntheticEvent,
  Pressable,
  StyleSheet,
  Text,
  useWindowDimensions,
  View,
} from "react-native";
import Animated, {
  Easing,
  interpolate,
  runOnJS,
  type SharedValue,
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
} from "react-native-reanimated";

import { useAppTheme } from "@/theme/useAppTheme";

// ─── Public API ────────────────────────────────────────────────────────────────

export interface HeroSlide {
  id: string;
  image: ImageSourcePropType;
  /** Short label shown in pill badge, e.g. "RENTALS" */
  tag: string;
  title: string;
  subtitle: string;
  onPress?: () => void;
}

export interface HeroCarouselProps {
  slides: readonly HeroSlide[];
  /** Section title displayed above the carousel */
  sectionTitle?: string | null;
  /** Right-side action label */
  sectionAction?: string | null;
  /** Callback when section action is pressed */
  onSectionAction?: () => void;
  /** Auto-play interval in ms. Set 0 to disable. @default 5000 */
  autoPlayMs?: number;
}

// ─── Constants ─────────────────────────────────────────────────────────────────

const SIDE_PADDING = 20;
const CARD_GAP = 0;
const CARD_BORDER_RADIUS = 0;
const CARD_HEIGHT = 198;
const PARALLAX_SHIFT = 24;
const AUTOPLAY_RESUME_DELAY = 3500;

const SPRING_SMOOTH = { damping: 28, stiffness: 170, mass: 0.9 } as const;

// ─── Main Component ────────────────────────────────────────────────────────────

export function HeroCarousel({
  slides,
  sectionTitle = "Popular For you",
  sectionAction = "View all",
  onSectionAction,
  autoPlayMs = 5000,
}: HeroCarouselProps) {
  const { width: screenWidth } = useWindowDimensions();
  const { colors } = useAppTheme();

  const cardWidth = Math.max(0, Math.round(screenWidth));
  const snapInterval = cardWidth + CARD_GAP;

  const scrollX = useSharedValue(0);
  const hasSectionHeader = Boolean(sectionTitle || sectionAction);

  // ─── Auto-play ─────────────────────────────────────────────────────────────
  const listRef = useRef<Animated.FlatList<HeroSlide>>(null);
  const activeIndexRef = useRef(0);
  const autoPlayTimer = useRef<ReturnType<typeof setInterval> | null>(null);
  const resumeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const isPaused = useRef(false);

  const startAutoPlay = useCallback(() => {
    if (autoPlayMs <= 0 || slides.length <= 1) return;
    if (autoPlayTimer.current) clearInterval(autoPlayTimer.current);

    autoPlayTimer.current = setInterval(() => {
      if (isPaused.current) return;
      const next = (activeIndexRef.current + 1) % slides.length;
      activeIndexRef.current = next;
      listRef.current?.scrollToOffset({ offset: next * snapInterval, animated: true });
    }, autoPlayMs);
  }, [autoPlayMs, slides.length, snapInterval]);

  const pauseAutoPlay = useCallback(() => {
    isPaused.current = true;
    if (resumeTimer.current) clearTimeout(resumeTimer.current);
  }, []);

  const scheduleResume = useCallback(() => {
    if (resumeTimer.current) clearTimeout(resumeTimer.current);
    resumeTimer.current = setTimeout(() => {
      isPaused.current = false;
    }, AUTOPLAY_RESUME_DELAY);
  }, []);

  useEffect(() => {
    startAutoPlay();
    return () => {
      if (autoPlayTimer.current) clearInterval(autoPlayTimer.current);
      if (resumeTimer.current) clearTimeout(resumeTimer.current);
    };
  }, [startAutoPlay]);

  // ─── Scroll handling ──────────────────────────────────────────────────────
  const scrollHandler = useAnimatedScrollHandler({
    onScroll: (event) => {
      scrollX.value = event.contentOffset.x;
    },
    onBeginDrag: () => {
      runOnJS(pauseAutoPlay)();
    },
    onEndDrag: () => {
      runOnJS(scheduleResume)();
    },
  });

  const handleMomentumEnd = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      const idx = Math.round(event.nativeEvent.contentOffset.x / snapInterval);
      activeIndexRef.current = Math.max(0, Math.min(idx, slides.length - 1));
    },
    [snapInterval, slides.length],
  );

  // ─── Render ────────────────────────────────────────────────────────────────
  return (
    <View style={styles.wrapper}>
      {/* Section Header */}
      {hasSectionHeader ? (
        <View style={styles.sectionHeader}>
          {sectionTitle ? (
            <Text style={[styles.sectionTitle, { color: colors.text }]}>
              {sectionTitle}
            </Text>
          ) : (
            <View />
          )}
          {sectionAction ? (
            <Pressable onPress={onSectionAction} hitSlop={8}>
              <Text style={[styles.sectionActionText, { color: colors.muted }]}>
                {sectionAction}
              </Text>
            </Pressable>
          ) : null}
        </View>
      ) : null}

      {/* Carousel */}
      <Animated.FlatList
        ref={listRef}
        data={slides as HeroSlide[]}
        keyExtractor={(item) => item.id}
        horizontal
        bounces={false}
        showsHorizontalScrollIndicator={false}
        scrollEventThrottle={16}
        decelerationRate="fast"
        disableIntervalMomentum
        snapToAlignment="start"
        snapToInterval={snapInterval}
        onScroll={scrollHandler}
        onMomentumScrollEnd={handleMomentumEnd}
        contentContainerStyle={{
          paddingLeft: 0,
          paddingRight: 0,
        }}
        ItemSeparatorComponent={() => <View style={{ width: CARD_GAP }} />}
        renderItem={({ item, index }) => (
          <CarouselCard
            slide={item}
            index={index}
            scrollX={scrollX}
            cardWidth={cardWidth}
            snapInterval={snapInterval}
          />
        )}
      />

    </View>
  );
}

// ─── Card ──────────────────────────────────────────────────────────────────────

interface CarouselCardProps {
  slide: HeroSlide;
  index: number;
  scrollX: SharedValue<number>;
  cardWidth: number;
  snapInterval: number;
}

function CarouselCard({ slide, index, scrollX, cardWidth, snapInterval }: CarouselCardProps) {
  // ─── Scale animation on scroll ───────────────────────────────────────────
  const cardStyle = useAnimatedStyle(() => {
    const inputRange = [
      (index - 1) * snapInterval,
      index * snapInterval,
      (index + 1) * snapInterval,
    ];
    const scale = interpolate(scrollX.value, inputRange, [0.985, 1, 0.985], "clamp");
    const opacity = interpolate(scrollX.value, inputRange, [0.9, 1, 0.9], "clamp");
    const translateY = interpolate(scrollX.value, inputRange, [3, 0, 3], "clamp");
    return {
      transform: [
        { scale: withSpring(scale, SPRING_SMOOTH) },
        { translateY: withSpring(translateY, SPRING_SMOOTH) },
      ],
      opacity: withTiming(opacity, { duration: 320, easing: Easing.out(Easing.cubic) }),
    };
  });

  const copyStyle = useAnimatedStyle(() => {
    const inputRange = [
      (index - 1) * snapInterval,
      index * snapInterval,
      (index + 1) * snapInterval,
    ];
    const opacity = interpolate(scrollX.value, inputRange, [0, 1, 0], "clamp");
    const translateY = interpolate(scrollX.value, inputRange, [14, 0, 14], "clamp");

    return {
      opacity: withTiming(opacity, { duration: 260, easing: Easing.out(Easing.cubic) }),
      transform: [{ translateY: withSpring(translateY, SPRING_SMOOTH) }],
    };
  });

  // ─── Parallax image shift ────────────────────────────────────────────────
  const imageStyle = useAnimatedStyle(() => {
    const translateX = interpolate(
      scrollX.value,
      [(index - 1) * snapInterval, index * snapInterval, (index + 1) * snapInterval],
      [PARALLAX_SHIFT, 0, -PARALLAX_SHIFT],
    );
    return { transform: [{ translateX }] };
  });

  return (
    <Animated.View style={[{ width: cardWidth, height: CARD_HEIGHT }, cardStyle]}>
      <View style={[styles.card, { width: cardWidth }]}>
        {/* Layer 0 ── Background image with parallax ── */}
        <Animated.Image
          source={slide.image}
          resizeMode="cover"
          style={[
            styles.bgImage,
            {
              width: cardWidth + PARALLAX_SHIFT * 2,
              height: CARD_HEIGHT,
            },
            imageStyle,
          ]}
        />

        {/* Layer 1 ── Bottom gradient scrim ──
             FIX: No `elevation` prop — that was causing Android to render
             the gradient ABOVE the text layer despite lower zIndex.
             Using only `zIndex` for correct stacking. */}
        <LinearGradient
          colors={["transparent", "rgba(0,0,0,0.20)", "rgba(0,0,0,0.82)"]}
          locations={[0, 0.3, 1]}
          style={styles.gradientScrim}
          pointerEvents="none"
        />

        {/* Layer 2 ── Top chrome: tag pill + bookmark ── */}
        <View style={styles.topRow}>
          <View style={styles.tagPill}>
            <Text style={styles.tagPillText}>{slide.tag}</Text>
          </View>

        </View>

        {/* Layer 3 ── Bottom copy block (over the gradient) ── */}
        <Animated.View style={[styles.copyBlock, copyStyle]}>
          <Text numberOfLines={1} style={styles.cardTitle}>
            {slide.title}
          </Text>
          <Text numberOfLines={2} style={styles.cardSubtitle}>
            {slide.subtitle}
          </Text>
        </Animated.View>
      </View>
    </Animated.View>
  );
}

// ─── Pagination Dot ────────────────────────────────────────────────────────────

// ─── Styles ────────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  wrapper: {
    paddingTop: 0,
  },

  // ─ Section Header ─────────────────────────────────────────────────────────
  sectionHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: SIDE_PADDING,
    paddingBottom: 16,
    paddingTop: 12,
  },
  sectionTitle: {
    fontSize: 22,
    lineHeight: 28,
    fontWeight: "800",
    letterSpacing: -0.4,
  },
  sectionActionText: {
    fontSize: 14,
    fontWeight: "600",
  },

  // ─ Card ─────────────────────────────────────────────────────────────────────
  card: {
    height: CARD_HEIGHT,
    borderRadius: CARD_BORDER_RADIUS,
    overflow: "hidden",
    backgroundColor: "#1A1A1C",
    elevation: 0,
    shadowColor: "transparent",
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0,
    shadowRadius: 0,
  },

  // ─ Background image ────────────────────────────────────────────────────────
  bgImage: {
    position: "absolute",
    top: 0,
    left: -PARALLAX_SHIFT,
    zIndex: 0,
  },

  // ─ Gradient scrim ──────────────────────────────────────────────────────────
  // FIX: zIndex ONLY, NO elevation. `elevation` on Android creates a separate
  // native view layer that ignores zIndex ordering, which was painting the
  // gradient OVER the text despite the text having zIndex: 3.
  gradientScrim: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    height: "65%",
    zIndex: 1,
  },

  // ─ Top chrome ───────────────────────────────────────────────────────────────
  topRow: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "flex-start",
    paddingHorizontal: 14,
    paddingTop: 12,
    zIndex: 4,
  },
  tagPill: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 999,
    backgroundColor: "#FFFFFF",
  },
  tagPillText: {
    fontSize: 10,
    fontWeight: "800",
    color: "#0B0B0C",
    letterSpacing: 0.8,
    textTransform: "uppercase",
  },
  // ─ Bottom copy ──────────────────────────────────────────────────────────────
  copyBlock: {
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 0,
    paddingHorizontal: 16,
    paddingBottom: 18,
    gap: 5,
    zIndex: 3,
  },
  cardTitle: {
    color: "#FFFFFF",
    fontSize: 21,
    lineHeight: 25,
    fontWeight: "800",
  },
  cardSubtitle: {
    color: "rgba(255,255,255,0.9)",
    fontSize: 12,
    lineHeight: 17,
    fontWeight: "600",
    maxWidth: "94%",
  },

  // ─ Pagination ───────────────────────────────────────────────────────────────
});
