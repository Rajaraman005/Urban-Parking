import type { ImageSourcePropType } from "react-native";

export interface OnboardingSlide {
  id: string;
  brandLabel: string;
  title: string;
  description: string;
  image: ImageSourcePropType;
}

export const onboardingSlides: [OnboardingSlide, ...OnboardingSlide[]] = [
  {
    id: "lend-parking-space",
    brandLabel: "Smart Parking",
    title: "EARN FROM YOUR\nPARKING SPACE",
    description:
      "Monetize your unused space effortlessly. Set pricing, availability, and rules in just a few taps.",
    image: require("../../../assets/onboarding_screen_img/img_1.jpg"),
  },
  {
    id: "host-space",
    brandLabel: "Host & Earn",
    title: "LIST & MANAGE\nYOUR SPACE",
    description:
      "Offer secure parking for bikes and cars. Control bookings, pricing, and availability with ease.",
    image: {
      uri: "https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?auto=format&fit=crop&w=1200&q=90",
    },
  },
  {
    id: "mobility-service",
    brandLabel: "Mobility Hub",
    title: "RENTALS & CAR\nCARE SERVICES",
    description:
      "Access bike and car rentals, washing, charging, and essential services all in one platform.",
    image: {
      uri: "https://images.unsplash.com/photo-1607860108855-64acf2078ed9?auto=format&fit=crop&w=1200&q=90",
    },
  },
];
