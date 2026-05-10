import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:urban_parking/features/auth/domain/auth_repository.dart';
import 'package:urban_parking/features/auth/domain/auth_state.dart';
import 'package:urban_parking/features/auth/presentation/auth_controller.dart';
import 'package:urban_parking/features/parking/domain/owner_parking_repository.dart';
import 'package:urban_parking/features/user_setup/domain/user_setup_repository.dart';
import 'package:urban_parking/features/user_setup/domain/user_setup_state.dart';
import 'package:urban_parking/features/user_setup/presentation/user_setup_controller.dart';
import 'package:urban_parking/features/user_setup/presentation/user_setup_screens.dart';

void main() {
  testWidgets('profile setup renders real fields and backs to intent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        repository: _FakeUserSetupRepository(
          state: const UserSetupState(intent: 'park', step: 'profile'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal details'), findsOneWidget);
    expect(find.text('Setup'), findsNothing);
    expect(find.text('Tell us about you'), findsNothing);
    expect(
      find.text(
        'These details help us keep bookings and account support secure.',
      ),
      findsNothing,
    );
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Upload photo'), findsNothing);
    expect(find.text('TE'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    expect(find.text('Prefer not'), findsNothing);
    expect(
      find.text('Profile validation preserves Indian mobile'),
      findsNothing,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(find.text('Date of birth'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Intent screen'), findsOneWidget);
  });

  testWidgets('profile setup starts with initials instead of Google avatar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        authRepository: _FakeAuthRepository(
          avatarUrl: 'https://lh3.googleusercontent.com/a/example-avatar',
          fullName: 'Raja Raman',
        ),
        repository: _FakeUserSetupRepository(
          state: const UserSetupState(intent: 'park', step: 'profile'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RA'), findsOneWidget);
    expect(find.text('Upload photo'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('renter profile save routes to vehicle details', (tester) async {
    final repository = _FakeUserSetupRepository(
      state: const UserSetupState(intent: 'park', step: 'profile'),
    );

    await tester.pumpWidget(_harness(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Male'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(repository.savedProfile, isNotNull);
    expect(repository.savedProfile!['phone'], '9876543210');
    expect(repository.savedProfile!['gender'], 'male');
    expect(repository.savedProfile!['dob'], '01/01/1990');
    expect(find.text('Vehicle details'), findsOneWidget);
    expect(find.text('Step 2 of 2'), findsNothing);
    expect(find.text('Start finding parking'), findsOneWidget);
  });

  testWidgets('mobile field normalizes pasted +91 numbers before saving', (
    tester,
  ) async {
    final repository = _FakeUserSetupRepository(
      state: const UserSetupState(intent: 'park', step: 'profile'),
    );

    await tester.pumpWidget(_harness(repository: repository));
    await tester.pumpAndSettle();

    final phoneField = find.byType(EditableText).at(1);
    await tester.enterText(phoneField, '+91 98765 43210');
    await tester.tap(find.text('Male'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(repository.savedProfile!['phone'], '9876543210');
    expect(find.text('Vehicle details'), findsOneWidget);
  });

  testWidgets('mobile field rejects repeated placeholder digits', (
    tester,
  ) async {
    final repository = _FakeUserSetupRepository(
      state: const UserSetupState(intent: 'park', step: 'profile'),
    );

    await tester.pumpWidget(_harness(repository: repository));
    await tester.pumpAndSettle();

    final phoneField = find.byType(EditableText).at(1);
    await tester.enterText(phoneField, '9999999999');
    await tester.tap(find.text('Male'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a real mobile number, not repeated digits'),
      findsOneWidget,
    );
    expect(repository.savedProfile, isNull);
  });

  testWidgets('vehicle details save completes setup and routes to search', (
    tester,
  ) async {
    final repository = _FakeUserSetupRepository(
      state: const UserSetupState(intent: 'park', step: 'vehicle_details'),
    );

    await tester.pumpWidget(
      _harness(initialLocation: '/setup/vehicle', repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vehicle type'), findsOneWidget);
    expect(find.text('Bike'), findsOneWidget);
    expect(find.text('Car'), findsOneWidget);

    await tester.tap(find.text('Bike'));
    await tester.enterText(find.byType(EditableText).at(0), 'tn 09 ab 1234');
    await tester.enterText(find.byType(EditableText).at(1), 'Honda');
    await tester.enterText(find.byType(EditableText).at(2), 'Activa');
    await tester.tap(find.text('Start finding parking'));
    await tester.pumpAndSettle();

    expect(repository.savedVehicle, isNotNull);
    expect(repository.savedVehicle!['vehicleType'], 'bike');
    expect(repository.savedVehicle!['vehicleRegistration'], 'TN09AB1234');
    expect(repository.savedVehicle!['vehicleMake'], 'Honda');
    expect(repository.savedVehicle!['vehicleModel'], 'Activa');
    expect(find.text('Search screen'), findsOneWidget);
  });

  testWidgets('vehicle registration accepts fancy numbers and pads serial', (
    tester,
  ) async {
    final repository = _FakeUserSetupRepository(
      state: const UserSetupState(intent: 'park', step: 'vehicle_details'),
    );

    await tester.pumpWidget(
      _harness(initialLocation: '/setup/vehicle', repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Car'));
    await tester.enterText(find.byType(EditableText).at(0), 'tn 09 ab 7');
    await tester.tap(find.text('Start finding parking'));
    await tester.pumpAndSettle();

    expect(repository.savedVehicle!['vehicleType'], 'car');
    expect(repository.savedVehicle!['vehicleRegistration'], 'TN09AB0007');
    expect(find.text('Search screen'), findsOneWidget);
  });

  testWidgets('vehicle registration rejects incomplete values', (tester) async {
    final repository = _FakeUserSetupRepository(
      state: const UserSetupState(intent: 'park', step: 'vehicle_details'),
    );

    await tester.pumpWidget(
      _harness(initialLocation: '/setup/vehicle', repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bike'));
    await tester.enterText(find.byType(EditableText).at(0), 'TN');
    await tester.tap(find.text('Start finding parking'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter the full registration number, like TN 09 AB 1234'),
      findsOneWidget,
    );
    expect(repository.savedVehicle, isNull);
  });

  testWidgets('date of birth opens the branded bottom sheet picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        repository: _FakeUserSetupRepository(
          state: const UserSetupState(intent: 'park', step: 'profile'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();

    await tester.tap(find.text('01/01/1990'));
    await tester.pumpAndSettle();

    expect(find.text('Selected date'), findsOneWidget);
    expect(find.text('Use date'), findsOneWidget);
    expect(find.text('OK'), findsNothing);
  });

  testWidgets('date of birth picker defaults to 14 Oct 1999 when empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        authRepository: _FakeAuthRepository(includeDob: false),
        repository: _FakeUserSetupRepository(
          state: const UserSetupState(intent: 'park', step: 'profile'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose date of birth'));
    await tester.pumpAndSettle();

    expect(find.text('14 Oct 1999'), findsOneWidget);
    expect(find.text('Use date'), findsOneWidget);
  });

  testWidgets('date of birth picker clears phone focus after closing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _harness(
        repository: _FakeUserSetupRepository(
          state: const UserSetupState(intent: 'park', step: 'profile'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final phoneField = find.byType(EditableText).at(1);
    await tester.tap(phoneField);
    await tester.enterText(phoneField, '638634873');
    await tester.pump();

    expect(tester.widget<EditableText>(phoneField).focusNode.hasFocus, isTrue);

    await tester.tap(find.text('01/01/1990'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use date'));
    await tester.pumpAndSettle();

    expect(tester.widget<EditableText>(phoneField).focusNode.hasFocus, isFalse);
  });
}

Widget _harness({
  AuthRepository? authRepository,
  String initialLocation = '/setup/profile',
  required _FakeUserSetupRepository repository,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/setup/profile',
        builder: (_, _) => const UserSetupProfileScreen(),
      ),
      GoRoute(
        path: '/setup/vehicle',
        builder: (_, _) => const UserSetupVehicleScreen(),
      ),
      GoRoute(
        path: '/setup/intent',
        builder: (_, _) => const Scaffold(body: Text('Intent screen')),
      ),
      GoRoute(
        path: '/setup/host-basics',
        builder: (_, _) => const Scaffold(body: Text('Host basics screen')),
      ),
      GoRoute(
        path: '/search',
        builder: (_, _) => const Scaffold(body: Text('Search screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        authRepository ?? _FakeAuthRepository(),
      ),
      userSetupRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    String? avatarUrl,
    DateTime? dob,
    String fullName = 'Test User',
    bool includeDob = true,
  }) : _avatarUrl = avatarUrl,
       _dob = includeDob ? dob ?? DateTime(1990, 1, 1) : null,
       _fullName = fullName;

  final String? _avatarUrl;
  final DateTime? _dob;
  final String _fullName;

  @override
  Future<AuthState> hydrate() async {
    return AuthState(
      status: AuthStatus.authenticated,
      user: const AppUser(id: 'user-1', email: 'user@example.com'),
      profile: UserProfile(
        id: 'user-1',
        avatarUrl: _avatarUrl,
        dob: _dob,
        fullName: _fullName,
        gender: 'prefer_not_to_say',
        intent: 'park',
        phone: '9876543210',
        setupStep: 'profile',
      ),
    );
  }

  @override
  Future<AuthState> refreshSessionOrLogout() => hydrate();

  @override
  Future<void> requestSignupOtp() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<AuthState> signInWithEmailPassword({
    required String email,
    required String password,
  }) => hydrate();

  @override
  Future<AuthState> signInWithGoogle() => hydrate();

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthState> signUpWithEmailPassword({
    required String fullName,
    required String email,
    required String password,
  }) => hydrate();

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> verifySignupOtp({required String token}) async {}
}

class _FakeUserSetupRepository implements UserSetupRepository {
  _FakeUserSetupRepository({required UserSetupState state}) : _state = state;

  UserSetupState _state;
  Map<String, String>? savedProfile;
  Map<String, String?>? savedVehicle;

  @override
  Future<UserSetupState> loadSnapshot() async => _state;

  @override
  Future<HostListingDraft?> loadHostDraftResumeCandidate() async => null;

  @override
  Future<UserSetupState> saveIntent(String intent) async {
    _state = UserSetupState(intent: intent, step: 'profile');
    return _state;
  }

  @override
  Future<UserSetupState> saveProfile({
    required String fullName,
    required String phone,
    required String gender,
    required String dob,
  }) async {
    savedProfile = {
      'fullName': fullName,
      'phone': phone,
      'gender': gender,
      'dob': dob,
    };
    _state = UserSetupState(intent: _state.intent, step: 'vehicle_details');
    return _state;
  }

  @override
  Future<UserSetupState> saveVehicleDetails({
    bool createNew = false,
    String? previousVehicleRegistration,
    String? vehicleId,
    String? vehicleMake,
    String? vehicleModel,
    required String vehicleRegistration,
    required String vehicleType,
  }) async {
    savedVehicle = {
      'vehicleMake': vehicleMake,
      'vehicleModel': vehicleModel,
      'vehicleRegistration': vehicleRegistration,
      'vehicleType': vehicleType,
    };
    _state = const UserSetupState(intent: 'park', step: 'complete');
    return _state;
  }

  @override
  Future<UserSetupState> startHostListing({
    bool createNew = false,
    String? resumeDraftId,
    String? resumeStep,
  }) async => const UserSetupState(intent: 'host', step: 'host_basics');

  @override
  Future<List<ParkingAddressCandidate>> searchAddress(String query) async =>
      const [];

  @override
  Future<UserSetupState> saveHostBasics(HostBasicsDraftUpdate update) async =>
      _state;

  @override
  Future<UserSetupState> saveHostPricing(HostPricingDraftUpdate update) async =>
      _state;

  @override
  Future<UserSetupState> uploadHostPhoto(
    HostPhotoUploadCandidate image,
  ) async => _state;

  @override
  Future<UserSetupState> deleteHostPhoto(String photoId) async => _state;

  @override
  Future<UserSetupState> reorderHostPhotos(List<String> photoIds) async =>
      _state;

  @override
  Future<UserSetupState> markPhotosStepComplete() async => _state;

  @override
  Future<UserSetupState> submitForReview() async => _state;
}
