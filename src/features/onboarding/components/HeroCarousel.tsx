import { useCallback, useEffect, useRef, useState } from "react";
import { FlatList, View, type NativeScrollEvent, type NativeSyntheticEvent } from "react-native";

import { HeroCopyOverlay } from "@/features/onboarding/components/HeroCopyOverlay";
import { HeroSlide } from "@/features/onboarding/components/HeroSlide";
import { PaginationDots } from "@/features/onboarding/components/PaginationDots";
import type { OnboardingSlide } from "@/features/onboarding/data/onboardingSlides";

interface HeroCarouselProps {
  bottomOffset: number;
  height: number;
  slides: [OnboardingSlide, ...OnboardingSlide[]];
  topInset: number;
  width: number;
}

export function HeroCarousel({ bottomOffset, height, slides, topInset, width }: HeroCarouselProps) {
  const listRef = useRef<FlatList<OnboardingSlide>>(null);
  const isInteractingRef = useRef(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const activeSlide = slides[activeIndex] ?? slides[0];

  useEffect(() => {
    const interval = setInterval(() => {
      if (isInteractingRef.current) {
        return;
      }

      setActiveIndex((currentIndex) => {
        const nextIndex = (currentIndex + 1) % slides.length;
        listRef.current?.scrollToOffset({ offset: nextIndex * width, animated: true });
        return nextIndex;
      });
    }, 4200);

    return () => clearInterval(interval);
  }, [slides.length, width]);

  const onMomentumScrollEnd = useCallback(
    (event: NativeSyntheticEvent<NativeScrollEvent>) => {
      const nextIndex = Math.round(event.nativeEvent.contentOffset.x / width);
      setActiveIndex(Math.max(0, Math.min(nextIndex, slides.length - 1)));
      isInteractingRef.current = false;
    },
    [slides.length, width]
  );

  return (
    <View style={{ height, width }}>
      <FlatList
        ref={listRef}
        data={slides}
        horizontal
        pagingEnabled
        bounces={false}
        decelerationRate="fast"
        disableIntervalMomentum
        keyExtractor={(item) => item.id}
        onScrollBeginDrag={() => {
          isInteractingRef.current = true;
        }}
        onMomentumScrollEnd={onMomentumScrollEnd}
        onScrollToIndexFailed={() => undefined}
        showsHorizontalScrollIndicator={false}
        getItemLayout={(_, index) => ({ length: width, offset: width * index, index })}
        renderItem={({ item }) => <HeroSlide slide={item} topInset={topInset} width={width} />}
      />
      <View style={{ position: "absolute", bottom: bottomOffset + 82, left: 22, right: 22, alignItems: "flex-start" }}>
        <HeroCopyOverlay slide={activeSlide} />
      </View>
      <View style={{ position: "absolute", bottom: bottomOffset + 30, left: 0, right: 0 }}>
        <PaginationDots activeIndex={activeIndex} count={slides.length} />
      </View>
    </View>
  );
}
