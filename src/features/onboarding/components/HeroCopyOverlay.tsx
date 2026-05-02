import { StyleSheet, View } from "react-native";

import { AnimatedHeroTitle } from "@/features/onboarding/components/AnimatedHeroTitle";
import { GlassDescriptionCard } from "@/features/onboarding/components/GlassDescriptionCard";
import type { OnboardingSlide } from "@/features/onboarding/data/onboardingSlides";

interface HeroCopyOverlayProps {
  slide: OnboardingSlide;
}

export function HeroCopyOverlay({ slide }: HeroCopyOverlayProps) {
  return (
    <View pointerEvents="none" style={styles.container}>
      <AnimatedHeroTitle align="left" title={slide.title} />
      <GlassDescriptionCard text={slide.description} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: "flex-start",
    gap: 12,
    maxWidth: 334
  }
});
