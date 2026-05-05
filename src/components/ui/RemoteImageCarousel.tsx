import { useEffect, useMemo, useRef, useState } from "react";
import {
  Image,
  type LayoutChangeEvent,
  Pressable,
  ScrollView,
  StyleSheet,
  View,
} from "react-native";

import { useAppTheme } from "@/theme/useAppTheme";

interface RemoteImageCarouselProps {
  autoPlayMs?: number;
  borderRadius?: number;
  height: number;
  imageUrls: readonly string[];
  isAutoPlayEnabled?: boolean;
  onImagePress?: (index: number) => void;
}

const FALLBACK_IMAGE_URL =
  "https://images.unsplash.com/photo-1506521781263-d8422e82f27a";

export function RemoteImageCarousel({
  autoPlayMs = 4000,
  borderRadius = 8,
  height,
  imageUrls,
  isAutoPlayEnabled = true,
  onImagePress,
}: RemoteImageCarouselProps) {
  const { colors } = useAppTheme();
  const scrollRef = useRef<ScrollView>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const displayIndexRef = useRef(0);
  const [activeIndex, setActiveIndex] = useState(0);
  const [width, setWidth] = useState(0);

  const baseUrls = useMemo(() => {
    const urls = new Set<string>();
    for (const rawUrl of imageUrls) {
      const url = rawUrl.trim();
      if (url) urls.add(url);
    }
    if (urls.size === 0) {
      urls.add(FALLBACK_IMAGE_URL);
    }
    return [...urls];
  }, [imageUrls]);

  const slides = useMemo(
    () =>
      baseUrls.length > 1 ? [...baseUrls, baseUrls[0] ?? FALLBACK_IMAGE_URL] : baseUrls,
    [baseUrls],
  );

  useEffect(() => {
    displayIndexRef.current = 0;
    setActiveIndex(0);
    if (width > 0) {
      scrollRef.current?.scrollTo({ x: 0, animated: false });
    }
  }, [baseUrls, width]);

  useEffect(() => {
    if (timerRef.current) clearInterval(timerRef.current);
    if (!isAutoPlayEnabled || baseUrls.length < 2 || width <= 0 || autoPlayMs <= 0) {
      return;
    }

    timerRef.current = setInterval(() => {
      const nextDisplayIndex = displayIndexRef.current + 1;
      displayIndexRef.current = nextDisplayIndex;
      scrollRef.current?.scrollTo({
        x: nextDisplayIndex * width,
        animated: true,
      });
    }, autoPlayMs);

    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
      timerRef.current = null;
    };
  }, [autoPlayMs, baseUrls.length, isAutoPlayEnabled, width]);

  const handleLayout = (event: LayoutChangeEvent) => {
    const nextWidth = Math.round(event.nativeEvent.layout.width);
    if (nextWidth <= 0 || nextWidth == width) return;
    setWidth(nextWidth);
  };

  const handleScrollEnd = (offsetX: number) => {
    if (width <= 0) return;

    const nextDisplayIndex = Math.round(offsetX / width);
    displayIndexRef.current = nextDisplayIndex;

    if (baseUrls.length > 1 && nextDisplayIndex >= slides.length - 1) {
      displayIndexRef.current = 0;
      setActiveIndex(0);
      requestAnimationFrame(() => {
        scrollRef.current?.scrollTo({ x: 0, animated: false });
      });
      return;
    }

    const nextActiveIndex = baseUrls.length <= 1 ? 0 : nextDisplayIndex % baseUrls.length;
    setActiveIndex(nextActiveIndex);
  };

  return (
    <View
      onLayout={handleLayout}
      style={[
        styles.frame,
        {
          backgroundColor: colors.surface,
          borderRadius,
          height,
        },
      ]}
    >
      <ScrollView
        ref={scrollRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        scrollEventThrottle={16}
        onMomentumScrollEnd={(event) =>
          handleScrollEnd(event.nativeEvent.contentOffset.x)
        }
      >
        {slides.map((imageUrl, index) => {
          const resolvedIndex = baseUrls.length <= 1 ? 0 : index % baseUrls.length;
          const image = (
            <Image
              source={{ uri: imageUrl }}
              resizeMode="cover"
              style={{
                width: width || 1,
                height,
              }}
            />
          );

          if (!onImagePress) {
            return <View key={`${imageUrl}-${index}`}>{image}</View>;
          }

          return (
            <Pressable
              key={`${imageUrl}-${index}`}
              accessibilityHint="Opens the full screen image viewer"
              accessibilityLabel={`Open image ${resolvedIndex + 1}`}
              accessibilityRole="button"
              onPress={() => onImagePress(resolvedIndex)}
            >
              {image}
            </Pressable>
          );
        })}
      </ScrollView>
      <View style={styles.dots}>
        {baseUrls.map((_, index) => (
          <View
            key={`dot-${index}`}
            style={[
              styles.dot,
              {
                backgroundColor:
                  index === activeIndex
                    ? "rgba(255,255,255,0.96)"
                    : "rgba(255,255,255,0.48)",
                width: index === activeIndex ? 18 : 6,
              },
            ]}
          />
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  dot: {
    borderRadius: 999,
    height: 6,
    marginHorizontal: 3,
  },
  dots: {
    alignItems: "center",
    alignSelf: "center",
    backgroundColor: "rgba(0,0,0,0.22)",
    borderRadius: 999,
    bottom: 12,
    flexDirection: "row",
    paddingHorizontal: 7,
    paddingVertical: 5,
    position: "absolute",
  },
  frame: {
    overflow: "hidden",
  },
});
