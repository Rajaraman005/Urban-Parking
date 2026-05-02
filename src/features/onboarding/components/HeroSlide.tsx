import { ImageBackground, View } from "react-native";

import type { OnboardingSlide } from "@/features/onboarding/data/onboardingSlides";

import { OnboardingBrand } from "@/features/onboarding/components/OnboardingBrand";

interface HeroSlideProps {
  slide: OnboardingSlide;
  topInset: number;
  width: number;
}

export function HeroSlide({ slide, topInset, width }: HeroSlideProps) {
  return (
    <ImageBackground source={slide.image} resizeMode="cover" style={{ width, flex: 1 }}>
      <View style={{ flex: 1, backgroundColor: "rgba(0,0,0,0.36)" }}>
        <View
          style={{
            position: "absolute",
            top: topInset + 20,
            left: 0,
            right: 0,
            alignItems: "center"
          }}
        >
          <OnboardingBrand label={slide.brandLabel} />
        </View>
      </View>
    </ImageBackground>
  );
}
