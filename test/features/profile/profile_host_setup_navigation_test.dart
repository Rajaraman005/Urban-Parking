import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:urban_parking/config/app_providers.dart';
import 'package:urban_parking/features/auth/domain/auth_state.dart';
import 'package:urban_parking/features/auth/presentation/auth_controller.dart';
import 'package:urban_parking/features/parking/domain/owner_parking_repository.dart';
import 'package:urban_parking/features/profile/presentation/profile_screen.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/core/utils/location_service.dart';
import 'package:urban_parking/features/user_setup/domain/user_setup_repository.dart';
import 'package:urban_parking/features/user_setup/domain/user_setup_state.dart';
import 'package:urban_parking/features/user_setup/presentation/user_setup_controller.dart';
import 'package:urban_parking/features/user_setup/presentation/user_setup_screens.dart';

void main() {
  const validDescription =
      'Covered parking near the entrance with clear lighting and easy access.';

  testWidgets('profile host tile opens host setup basics', (tester) async {
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(_authenticatedState()),
          ),
          userSetupRepositoryProvider.overrideWithValue(
            _FakeUserSetupRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Host a parking space'));
    await tester.pumpAndSettle();

    expect(find.text('Parking space basics'), findsNothing);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Listing title'), findsOneWidget);
    expect(find.text('Search street, building, or landmark'), findsOneWidget);
    expect(find.text('Locality'), findsNothing);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('State'), findsOneWidget);
    expect(find.byTooltip('Use current location'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Old saved address'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Vehicle fit'), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('host-space-description-field')),
      find.byType(ListView),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('host-space-description-field')),
      findsOneWidget,
    );
    expect(find.text('Access instructions'), findsNothing);
    expect(
      find.textContaining('Address lookup, OSM reverse geocode'),
      findsNothing,
    );
  });

  testWidgets('new host setup opens before draft creation finishes', (
    tester,
  ) async {
    final router = _router();
    final repository = _FakeUserSetupRepository();
    final draftCreation = Completer<void>();
    repository.createNewBarrier = draftCreation.future;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(_authenticatedState()),
          ),
          userSetupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Host a parking space'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Parking space basics'), findsNothing);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Old saved address'), findsNothing);
    expect(find.text('Preparing listing'), findsNothing);

    draftCreation.complete();
    await tester.pumpAndSettle();
    expect(repository.startedCreateNew, isTrue);
  });

  testWidgets('profile host tile asks before resuming an existing draft', (
    tester,
  ) async {
    final router = _router();
    final repository = _FakeUserSetupRepository(hasResumeDraft: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(
              _authenticatedState(
                hostParkingDraftId: 'draft-1',
                setupStep: 'host_pricing',
              ),
            ),
          ),
          userSetupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Host a parking space'));
    await tester.pumpAndSettle();

    expect(find.text('Continue your draft?'), findsOneWidget);
    expect(find.text('Old draft'), findsOneWidget);
    expect(find.text('Continue draft'), findsOneWidget);
    expect(find.text('Start new listing'), findsOneWidget);

    await tester.tap(find.text('Continue draft'));
    await tester.pumpAndSettle();

    expect(find.text('Pricing'), findsOneWidget);
    expect(repository.startedCreateNew, isFalse);
  });

  testWidgets('profile host tile ignores stale deleted draft reference', (
    tester,
  ) async {
    final router = _router();
    final repository = _FakeUserSetupRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(
              _authenticatedState(
                hostParkingDraftId: 'deleted-draft',
                setupStep: 'host_photos',
              ),
            ),
          ),
          userSetupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Host a parking space'));
    await tester.pumpAndSettle();

    expect(find.text('Continue your draft?'), findsNothing);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Listing title'), findsOneWidget);
    expect(repository.startedCreateNew, isTrue);
  });

  testWidgets('profile host tile resumes the exact saved draft step', (
    tester,
  ) async {
    final router = _router();
    final repository = _FakeUserSetupRepository(
      hasResumeDraft: true,
      resumeCurrentStep: 'host_photos',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(
              _authenticatedState(
                hostParkingDraftId: 'draft-1',
                setupStep: 'host_basics',
              ),
            ),
          ),
          userSetupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Host a parking space'));
    await tester.pumpAndSettle();

    expect(find.text('Continue your draft?'), findsOneWidget);
    expect(find.text('Step 3 of 4'), findsOneWidget);

    await tester.tap(find.text('Continue draft'));
    await tester.pumpAndSettle();

    expect(find.text('Photos'), findsOneWidget);
    expect(repository.startedCreateNew, isFalse);
  });

  testWidgets('host setup app bar stays white while pricing scrolls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userSetupRepositoryProvider.overrideWithValue(
            _FakeUserSetupRepository(),
          ),
        ],
        child: const MaterialApp(home: HostSpacePricingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    AppBar appBar() => tester.widget<AppBar>(find.byType(AppBar).first);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('Pricing and availability'), findsNothing);
    expect(
      find.text(
        'Set when renters can book this space and how many slots are available.',
      ),
      findsNothing,
    );
    expect(appBar().backgroundColor, Colors.white);
    expect(appBar().scrolledUnderElevation, 0);
    expect(appBar().surfaceTintColor, Colors.transparent);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(appBar().backgroundColor, Colors.white);
    expect(appBar().scrolledUnderElevation, 0);
    expect(appBar().surfaceTintColor, Colors.transparent);
  });

  testWidgets('gps button applies current location before basics save', (
    tester,
  ) async {
    final router = _router();
    final repository = _FakeUserSetupRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(_authenticatedState()),
          ),
          locationServiceProvider.overrideWithValue(
            _FakeLocationService(
              const GeoPoint(latitude: 8.7139, longitude: 77.7567),
            ),
          ),
          userSetupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Host a parking space'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use current location'));
    await tester.pumpAndSettle();
    expect(find.text('8.713900, 77.756700'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Bike parking');
    await tester.enterText(fields.at(2), '12 Current Location Road');
    await tester.enterText(fields.at(3), 'Palayamkottai');
    await tester.enterText(fields.at(4), 'Tamil Nadu');
    await tester.enterText(fields.at(5), '627002');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('host-space-description-field')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-space-description-field')),
      validDescription,
    );
    await tester.scrollUntilVisible(
      find.text('Save basics'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save basics'));
    await tester.pumpAndSettle();

    expect(repository.savedBasics?.location.latitude, closeTo(8.7139, 0.0001));
    expect(
      repository.savedBasics?.location.longitude,
      closeTo(77.7567, 0.0001),
    );
    expect(repository.savedBasics?.city, 'Palayamkottai');
    expect(repository.savedBasics?.locality, 'Palayamkottai');
    expect(repository.savedBasics?.addressRaw?['state'], 'Tamil Nadu');
    expect(repository.savedBasics?.accessInstructions, validDescription);
  });

  testWidgets('host basics requires a 50-200 character description', (
    tester,
  ) async {
    final router = _router();
    final repository = _FakeUserSetupRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(_authenticatedState()),
          ),
          locationServiceProvider.overrideWithValue(
            _FakeLocationService(
              const GeoPoint(latitude: 8.7139, longitude: 77.7567),
            ),
          ),
          userSetupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Host a parking space'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use current location'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Bike parking');
    await tester.enterText(fields.at(2), '12 Current Location Road');
    await tester.enterText(fields.at(3), 'Palayamkottai');
    await tester.enterText(fields.at(4), 'Tamil Nadu');
    await tester.enterText(fields.at(5), '627002');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('host-space-description-field')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('host-space-description-field')),
      'Too short',
    );
    await tester.tap(find.text('Save basics'));
    await tester.pumpAndSettle();

    expect(
      find.text('Description must be at least 50 characters.'),
      findsOneWidget,
    );
    expect(repository.savedBasics, isNull);
  });

  testWidgets('host address search autocompletes while typing', (tester) async {
    final router = _router();
    final repository = _FakeUserSetupRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(_authenticatedState()),
          ),
          userSetupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Host a parking space'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Tirunelveli railway');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(repository.searchQueries, contains('Tirunelveli railway'));
    expect(find.text('12 Main Road, Chennai'), findsOneWidget);
  });

  testWidgets('profile host tile redirects guests to auth', (tester) async {
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(
              const AuthState(status: AuthStatus.unauthenticated),
            ),
          ),
          userSetupRepositoryProvider.overrideWithValue(
            _FakeUserSetupRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Host a parking space'));
    await tester.pumpAndSettle();

    expect(find.text('Auth'), findsOneWidget);
  });
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/setup/host-basics',
        builder: (_, state) => HostSpaceBasicsScreen(
          createNew: state.uri.queryParameters['new'] == '1',
        ),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, _) => const Scaffold(body: Text('Auth')),
      ),
      GoRoute(
        path: '/setup/host-pricing',
        builder: (_, _) => const Scaffold(body: Text('Pricing')),
      ),
      GoRoute(
        path: '/setup/host-photos',
        builder: (_, _) => const Scaffold(body: Text('Photos')),
      ),
    ],
  );
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initial);

  final AuthState _initial;

  @override
  Future<AuthState> build() async => _initial;
}

AuthState _authenticatedState({
  String? hostParkingDraftId,
  String? setupDraftId,
  String setupStep = 'host_basics',
}) {
  return AuthState(
    status: AuthStatus.authenticated,
    user: const AppUser(id: 'user-1', email: 'host@example.com'),
    profile: UserProfile(
      id: 'user-1',
      email: 'host@example.com',
      fullName: 'Test Host',
      hostParkingDraftId: hostParkingDraftId,
      setupDraftId: setupDraftId,
      setupStep: setupStep,
    ),
  );
}

class _FakeUserSetupRepository implements UserSetupRepository {
  _FakeUserSetupRepository({
    bool hasResumeDraft = false,
    String resumeCurrentStep = 'host_pricing',
  }) : _draft = HostListingDraft(
         id: 'draft-1',
         status: 'draft',
         version: 1,
         address: 'Old saved address',
         city: 'Old city',
         currentStep: resumeCurrentStep,
         locality: 'Old locality',
         location: const GeoPoint(latitude: 13.0827, longitude: 80.2707),
         parkingType: 'open',
         postalCode: '600001',
         stateName: 'Tamil Nadu',
         title: 'Old draft',
         vehicleFit: 'car',
       ),
       _hasResumeDraft = hasResumeDraft;

  Future<void>? createNewBarrier;
  HostBasicsDraftUpdate? savedBasics;
  final List<String> searchQueries = [];
  bool _hasResumeDraft;
  bool startedCreateNew = false;
  HostListingDraft _draft;

  @override
  Future<UserSetupState> loadSnapshot() async {
    if (!_hasResumeDraft) return const UserSetupState();
    return UserSetupState(
      draft: _draft,
      draftId: _draft.id,
      intent: 'host',
      step: 'host_basics',
    );
  }

  @override
  Future<HostListingDraft?> loadHostDraftResumeCandidate() async {
    return _hasResumeDraft ? _draft : null;
  }

  @override
  Future<UserSetupState> startHostListing({
    bool createNew = false,
    String? resumeDraftId,
    String? resumeStep,
  }) async {
    if (createNew) {
      startedCreateNew = true;
      await createNewBarrier;
      _draft = const HostListingDraft(
        id: 'draft-new',
        status: 'draft',
        version: 1,
        currentStep: 'host_basics',
      );
    }
    _hasResumeDraft = true;
    return UserSetupState(
      draft: _draft,
      draftId: _draft.id,
      intent: 'host',
      step: createNew
          ? 'host_basics'
          : resumeStep ?? _draft.currentStep ?? 'host_basics',
    );
  }

  @override
  Future<List<ParkingAddressCandidate>> searchAddress(String query) async {
    searchQueries.add(query);
    return const [
      ParkingAddressCandidate(
        address: '12 Main Road, Chennai',
        city: 'Chennai',
        confidence: 0.92,
        latitude: 13.0827,
        locality: 'Anna Nagar',
        longitude: 80.2707,
        postalCode: '600001',
        provider: 'nominatim',
      ),
    ];
  }

  @override
  Future<UserSetupState> saveHostBasics(HostBasicsDraftUpdate update) async {
    savedBasics = update;
    _draft = HostListingDraft(
      id: _draft.id,
      status: 'draft',
      version: _draft.version + 1,
      address: update.address,
      city: update.city,
      currentStep: 'host_pricing',
      locality: update.locality,
      location: update.location,
      parkingType: update.parkingType,
      postalCode: update.postalCode,
      stateName: update.stateName,
      title: update.title,
      vehicleFit: update.vehicleFit,
      accessInstructions: update.accessInstructions,
    );
    return UserSetupState(
      draft: _draft,
      draftId: _draft.id,
      intent: 'host',
      step: 'host_pricing',
    );
  }

  @override
  Future<UserSetupState> saveIntent(String intent) async {
    return UserSetupState(intent: intent, step: 'profile');
  }

  @override
  Future<UserSetupState> saveProfile({
    required String fullName,
    required String phone,
    required String gender,
    required String dob,
  }) async {
    return const UserSetupState(intent: 'host', step: 'host_basics');
  }

  @override
  Future<UserSetupState> saveHostPricing(HostPricingDraftUpdate update) async {
    return UserSetupState(
      draft: _draft,
      draftId: _draft.id,
      intent: 'host',
      step: 'host_photos',
    );
  }

  @override
  Future<UserSetupState> uploadHostPhoto(HostPhotoUploadCandidate image) async {
    return UserSetupState(
      draft: _draft,
      draftId: _draft.id,
      intent: 'host',
      step: 'host_photos',
    );
  }

  @override
  Future<UserSetupState> deleteHostPhoto(String photoId) async {
    return UserSetupState(
      draft: _draft,
      draftId: _draft.id,
      intent: 'host',
      step: 'host_photos',
    );
  }

  @override
  Future<UserSetupState> reorderHostPhotos(List<String> photoIds) async {
    return UserSetupState(
      draft: _draft,
      draftId: _draft.id,
      intent: 'host',
      step: 'host_photos',
    );
  }

  @override
  Future<UserSetupState> markPhotosStepComplete() async {
    return UserSetupState(
      draft: _draft,
      draftId: _draft.id,
      intent: 'host',
      step: 'host_review',
    );
  }

  @override
  Future<UserSetupState> submitForReview() async {
    return UserSetupState(
      draft: _draft,
      draftId: _draft.id,
      intent: 'host',
      step: 'complete',
    );
  }
}

class _FakeLocationService extends LocationService {
  _FakeLocationService(this._location);

  final GeoPoint _location;

  @override
  Future<LocationResult> currentLocation() async {
    return LocationResult(
      location: _location,
      permissionDenied: false,
      isFallback: false,
    );
  }
}
