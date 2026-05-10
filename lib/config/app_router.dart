import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/password_reset_screen.dart';
import '../features/booking/presentation/booking_screen.dart';
import '../features/booking/presentation/booking_schedule_screen.dart';
import '../features/booking/presentation/host_booking_requests_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/legal/data/legal_documents.dart';
import '../features/legal/presentation/legal_document_screen.dart';
import '../features/messaging/presentation/conversation_list_screen.dart';
import '../features/messaging/presentation/conversation_thread_screen.dart';
import '../features/notifications/presentation/notification_center_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/parking/presentation/search_screen.dart';
import '../features/parking/presentation/owned_parking_screen.dart';
import '../features/profile/presentation/personal_details_screen.dart';
import '../features/profile/presentation/privacy_booking_controls_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/vehicle_details_screen.dart';
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
        path: '/setup/vehicle',
        builder: (context, state) => const UserSetupVehicleScreen(),
      ),
      GoRoute(
        path: '/setup/host-basics',
        builder: (context, state) => HostSpaceBasicsScreen(
          createNew: state.uri.queryParameters['new'] == '1',
          instantLaunch: state.uri.queryParameters['launch'] == 'instant',
        ),
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
          resizeToAvoidBottomInset: !_usesFixedVehicleKeyboardLayout(
            state.uri.path,
          ),
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
          GoRoute(
            path: '/profile/personal-details',
            builder: (context, state) => const PersonalDetailsScreen(),
          ),
          GoRoute(
            path: '/profile/vehicle-details',
            builder: (context, state) => const VehicleDetailsScreen(),
          ),
          GoRoute(
            path: '/profile/vehicle-details/add',
            builder: (context, state) => const VehicleDetailsFormScreen(
              key: ValueKey('vehicle-details-add'),
            ),
          ),
          GoRoute(
            path: '/profile/vehicle-details/:vehicleId',
            builder: (context, state) => VehicleDetailsFormScreen(
              key: ValueKey(
                'vehicle-details-${state.pathParameters['vehicleId']}',
              ),
              vehicleId: state.pathParameters['vehicleId'],
            ),
          ),
          GoRoute(
            path: '/profile/privacy-booking-controls',
            builder: (context, state) => const PrivacyBookingControlsScreen(),
          ),
          GoRoute(
            path: '/profile/booking-requests',
            builder: (context, state) => const HostBookingRequestsScreen(),
          ),
          GoRoute(
            path: '/profile/my-spaces',
            builder: (context, state) => const OwnedParkingScreen(),
          ),
          GoRoute(
            path: '/profile/my-spaces/:spotId/edit',
            builder: (context, state) =>
                OwnedParkingEditScreen(spotId: state.pathParameters['spotId']!),
          ),
          GoRoute(
            path: '/profile/my-spaces/:spotId/address',
            builder: (context, state) => EditListingAddressScreen(
              spotId: state.pathParameters['spotId']!,
            ),
          ),
          GoRoute(
            path: '/profile/my-spaces/:spotId/pricing',
            builder: (context, state) => EditListingPricingScreen(
              spotId: state.pathParameters['spotId']!,
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationCenterScreen(),
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
        path: '/messages',
        builder: (context, state) => const ConversationListScreen(),
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (context, state) => ConversationThreadScreen(
          conversationId: state.pathParameters['conversationId']!,
        ),
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

bool _usesFixedVehicleKeyboardLayout(String location) {
  return location.startsWith('/profile/vehicle-details');
}
