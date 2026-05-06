import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/config/app_providers.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/features/auth/domain/auth_state.dart';
import 'package:urban_parking/features/auth/presentation/auth_controller.dart';
import 'package:urban_parking/features/booking/domain/booking_quote.dart';
import 'package:urban_parking/features/booking/presentation/booking_screen.dart';
import 'package:urban_parking/features/parking/domain/parking_repository.dart';
import 'package:urban_parking/features/parking/domain/parking_spot.dart';

void main() {
  testWidgets('owned listing host card follows live current profile', (
    tester,
  ) async {
    late _FakeAuthController authController;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() {
            authController = _FakeAuthController(
              _authState(fullName: 'Live Host One', phone: '9876543210'),
            );
            return authController;
          }),
          parkingRepositoryProvider.overrideWithValue(
            _FakeParkingRepository(
              spot: _spot(
                hostName: 'Stale Snapshot Host',
                isHostedByCurrentUser: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: BookingScreen(spotId: 'spot-1')),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Host Information'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Live Host One'), findsOneWidget);
    expect(find.text('Stale Snapshot Host'), findsNothing);

    authController.emitProfile(
      const UserProfile(
        id: 'user-1',
        fullName: 'Live Host Two',
        email: 'host@example.com',
        phone: '9123456789',
        version: 2,
      ),
    );
    await tester.pump();

    expect(find.text('Live Host Two'), findsOneWidget);
    expect(find.text('Live Host One'), findsNothing);
  });

  testWidgets('other listings keep their fetched host snapshot', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(_authState(fullName: 'Current User')),
          ),
          parkingRepositoryProvider.overrideWithValue(
            _FakeParkingRepository(
              spot: _spot(hostName: 'Other Host', isHostedByCurrentUser: false),
            ),
          ),
        ],
        child: const MaterialApp(home: BookingScreen(spotId: 'spot-1')),
      ),
    );

    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Host Information'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Other Host'), findsOneWidget);
    expect(find.text('Current User'), findsNothing);
  });
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initial);

  final AuthState _initial;

  @override
  Future<AuthState> build() async => _initial;

  void emitProfile(UserProfile profile) {
    replaceProfile(profile);
  }
}

class _FakeParkingRepository implements ParkingRepository {
  const _FakeParkingRepository({required ParkingSpot spot}) : _spot = spot;

  final ParkingSpot _spot;

  @override
  Future<ParkingSpot> getById(
    String id, {
    ParkingSpotFetchPolicy fetchPolicy = ParkingSpotFetchPolicy.cacheFirst,
  }) async => _spot;

  @override
  Future<ParkingSpot> refreshById(String id) async => _spot;

  @override
  Future<BookingQuote> quoteBooking({
    required String spotId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    return BookingQuote(
      spotId: spotId,
      startAt: startAt,
      endAt: endAt,
      subtotal: 50,
      platformFee: 8,
      taxes: 1,
      total: 59,
      currency: 'INR',
    );
  }

  @override
  Future<List<ParkingSpot>> searchNearby({
    required GeoPoint center,
    required double radiusKm,
  }) async {
    return [_spot];
  }
}

AuthState _authState({required String fullName, String? phone}) {
  return AuthState(
    status: AuthStatus.authenticated,
    user: const AppUser(id: 'user-1', email: 'host@example.com'),
    profile: UserProfile(
      id: 'user-1',
      fullName: fullName,
      email: 'host@example.com',
      phone: phone,
    ),
  );
}

ParkingSpot _spot({
  required String hostName,
  required bool isHostedByCurrentUser,
}) {
  final tomorrow = DateTime.now().add(const Duration(days: 1));
  return ParkingSpot(
    id: 'spot-1',
    title: 'Owned parking',
    address: '12 Test Street',
    locality: 'Test',
    distanceKm: 1.2,
    rating: 4.8,
    reviewCount: 24,
    price: 50,
    currency: 'INR',
    cadence: BookingCadence.hourly,
    availableFrom: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9),
    availableUntil: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 13),
    slotsAvailable: 1,
    location: const GeoPoint(latitude: 13.08, longitude: 80.27),
    amenities: const [ParkingAmenity.covered],
    imageUrl: 'https://example.com/parking.jpg',
    hostName: hostName,
    hostPhone: '9000000000',
    isHostedByCurrentUser: isHostedByCurrentUser,
  );
}
