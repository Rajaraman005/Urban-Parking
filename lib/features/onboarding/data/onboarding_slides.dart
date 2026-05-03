class OnboardingSlide {
  const OnboardingSlide({
    required this.image,
    required this.title,
    required this.subtitle,
  });

  final String image;
  final String title;
  final String subtitle;
}

const onboardingSlides = [
  OnboardingSlide(
    image: 'src/assets/onboarding_screen_img/img_1.jpg',
    title: 'Parking, rentals, and vehicle help nearby',
    subtitle: 'Find trusted options around you without bouncing between apps.',
  ),
  OnboardingSlide(
    image: 'src/assets/onboarding_screen_img/user_role/parking.jpg',
    title: 'Book spaces that fit your day',
    subtitle: 'Compare distance, availability, and price before you reserve.',
  ),
  OnboardingSlide(
    image: 'src/assets/onboarding_screen_img/user_role/parking_space.jpg',
    title: 'Host your unused parking space',
    subtitle: 'Create a listing, upload photos, and submit it for review.',
  ),
];
