import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/password_reset_screen.dart';
import '../features/booking/presentation/booking_screen.dart';
import '../features/booking/presentation/booking_schedule_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/legal/data/legal_documents.dart';
import '../features/legal/presentation/legal_document_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/parking/presentation/search_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/rental/presentation/rental_screen.dart';
import '../features/services/presentation/services_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/user_setup/presentation/user_setup_screens.dart';
import '../shared/widgets/tab_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => AuthScreen(
          initialMode: state.uri.queryParameters['mode'] ?? 'login',
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const PasswordResetScreen(),
      ),
      GoRoute(
        path: '/setup/intent',
        builder: (context, state) => const UserSetupIntentScreen(),
      ),
      GoRoute(
        path: '/setup/profile',
        builder: (context, state) => const UserSetupProfileScreen(),
      ),
      GoRoute(
        path: '/setup/host-basics',
        builder: (context, state) => const HostSpaceBasicsScreen(),
      ),
      GoRoute(
        path: '/setup/host-pricing',
        builder: (context, state) => const HostSpacePricingScreen(),
      ),
      GoRoute(
        path: '/setup/host-photos',
        builder: (context, state) => const HostSpacePhotosScreen(),
      ),
      GoRoute(
        path: '/setup/host-review',
        builder: (context, state) => const HostSpaceReviewScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => TabShell(
          currentIndex: _tabIndexForLocation(state.uri.path),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/rental',
            builder: (context, state) => const RentalScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/services',
            builder: (context, state) => const ServicesScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/booking/:spotId',
        builder: (context, state) =>
            BookingScreen(spotId: state.pathParameters['spotId']!),
      ),
      GoRoute(
        path: '/booking/:spotId/schedule',
        builder: (context, state) =>
            BookingScheduleScreen(spotId: state.pathParameters['spotId']!),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) =>
            const LegalDocumentScreen(document: privacyPolicy),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) =>
            const LegalDocumentScreen(document: termsOfUse),
      ),
    ],
  );
});

int _tabIndexForLocation(String location) {
  if (location.startsWith('/rental')) return 1;
  if (location.startsWith('/search')) return 2;
  if (location.startsWith('/services')) return 3;
  if (location.startsWith('/profile')) return 4;
  return 0;
}
