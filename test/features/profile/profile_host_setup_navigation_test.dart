import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:urban_parking/config/app_providers.dart';
import 'package:urban_parking/features/auth/domain/auth_state.dart';
import 'package:urban_parking/features/auth/presentation/auth_controller.dart';
import 'package:urban_parking/features/parking/domain/owner_parking_repository.dart';
import 'package:urban_parking/features/profile/data/profile_vehicle_repository.dart';
import 'package:urban_parking/features/profile/domain/profile_vehicle.dart';
import 'package:urban_parking/features/profile/presentation/profile_screen.dart';
import 'package:urban_parking/features/profile/presentation/vehicle_details_screen.dart';
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

  testWidgets(
    'host launch does not wait for draft lookup when profile has no draft',
    (tester) async {
      final router = _router();
      final repository = _FakeUserSetupRepository();
      final resumeLookup = Completer<void>();
      repository.resumeLookupBarrier = resumeLookup.future;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeAuthController(
                _authenticatedState(setupStep: 'profile'),
              ),
            ),
            userSetupRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Host a parking space'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(repository.startedCreateNew, isTrue);

      resumeLookup.complete();
    },
  );

  testWidgets('host launch does not wait for stale profile draft lookup', (
    tester,
  ) async {
    final router = _router();
    final repository = _FakeUserSetupRepository();
    final resumeLookup = Completer<void>();
    repository.resumeLookupBarrier = resumeLookup.future;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(
              _authenticatedState(
                hostParkingDraftId: 'stale-draft',
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('Continue your draft?'), findsNothing);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(repository.startedCreateNew, isTrue);

    resumeLookup.complete();
  });

  testWidgets('instant host launch defers map until after first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userSetupRepositoryProvider.overrideWithValue(
            _FakeUserSetupRepository(),
          ),
        ],
        child: const MaterialApp(
          home: HostSpaceBasicsScreen(instantLaunch: true),
        ),
      ),
    );

    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.byIcon(Icons.map_outlined), findsOneWidget);
    expect(find.byTooltip('Use current location'), findsNothing);

    await tester.pump();
    expect(find.byTooltip('Use current location'), findsOneWidget);
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
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Host a parking space'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsNothing);
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
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Host a parking space'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsNothing);
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

  testWidgets('parking profile hides hosting and shows vehicle details', (
    tester,
  ) async {
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(
              _authenticatedState(
                intent: 'park',
                setupStep: 'complete',
                vehicleMake: 'Honda',
                vehicleModel: 'Activa',
                vehicleRegistration: 'TN09AB1234',
                vehicleType: 'bike',
              ),
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

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Vehicle details'), findsOneWidget);
    expect(find.text('Bike - TN 09 AB 1234 - Honda Activa'), findsOneWidget);
    expect(find.text('Privacy & Booking Controls'), findsNothing);
    expect(find.text('Hosting'), findsNothing);
    expect(find.text('Host a parking space'), findsNothing);
    expect(find.text('My parking spaces'), findsNothing);
  });

  testWidgets('parking profile vehicle details can be updated', (tester) async {
    final router = _router();
    final repository = _FakeUserSetupRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(
              _authenticatedState(
                intent: 'park',
                setupStep: 'complete',
                vehicleMake: 'Honda',
                vehicleModel: 'Activa',
                vehicleRegistration: 'TN09AB1234',
                vehicleType: 'bike',
              ),
            ),
          ),
          userSetupRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vehicle details'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Vehicle details'), findsOneWidget);
    expect(find.text('TN 09 AB 1234'), findsOneWidget);
    expect(find.text('Honda Activa'), findsOneWidget);
    expect(find.byTooltip('Add vehicle'), findsOneWidget);
    expect(find.text('Save vehicle'), findsNothing);

    await tester.tap(find.text('TN 09 AB 1234'));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle details'), findsOneWidget);
    expect(find.text('Registration number'), findsOneWidget);
    expect(find.text('Save vehicle'), findsOneWidget);

    await tester.tap(find.byType(TextFormField).first);
    await tester.pumpAndSettle();
    expect(find.text('Save vehicle'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.text('Save vehicle'), findsOneWidget);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('Save vehicle'), findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Save vehicle'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add vehicle'));
    await tester.pumpAndSettle();
    expect(find.text('Add vehicle'), findsOneWidget);
    expect(find.text('Registration pending'), findsOneWidget);
    expect(find.text('Honda Activa'), findsNothing);
    final blankFields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(blankFields.at(0)).controller?.text,
      '',
    );
    expect(
      tester.widget<TextFormField>(blankFields.at(1)).controller?.text,
      '',
    );
    expect(
      tester.widget<TextFormField>(blankFields.at(2)).controller?.text,
      '',
    );

    await tester.tap(find.text('Car'));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'TN10CD5678');
    await tester.enterText(fields.at(1), 'Hyundai');
    await tester.enterText(fields.at(2), 'i20');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save vehicle'));
    await tester.tap(find.text('Save vehicle'));
    await tester.pumpAndSettle();

    expect(repository.savedVehicleType, 'car');
    expect(repository.savedVehicleCreateNew, isTrue);
    expect(repository.savedVehicleId, isNull);
    expect(repository.savedVehicleRegistration, 'TN10CD5678');
    expect(repository.savedVehicleMake, 'Hyundai');
    expect(repository.savedVehicleModel, 'i20');
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Vehicle details saved'), findsOneWidget);
    expect(find.text('Vehicle details'), findsOneWidget);
    expect(find.text('TN 09 AB 1234'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Bike - TN 09 AB 1234 - Honda Activa'), findsOneWidget);
  });

  testWidgets('parking profile vehicle details shows every saved vehicle', (
    tester,
  ) async {
    final router = _router();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(
              _authenticatedState(
                intent: 'park',
                setupStep: 'complete',
                vehicleMake: 'Honda',
                vehicleModel: 'City',
                vehicleRegistration: 'TN09AB1234',
                vehicleType: 'car',
              ),
            ),
          ),
          profileVehiclesProvider.overrideWith(
            (ref) async => const [
              ProfileVehicle(
                id: 'vehicle-car',
                userId: 'user-1',
                type: 'car',
                registration: 'TN09AB1234',
                make: 'Honda',
                model: 'City',
                isPrimary: true,
              ),
              ProfileVehicle(
                id: 'vehicle-bike',
                userId: 'user-1',
                type: 'bike',
                registration: 'TN10CD5678',
                make: 'Yamaha',
                model: 'R15',
              ),
            ],
          ),
          userSetupRepositoryProvider.overrideWithValue(
            _FakeUserSetupRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 vehicles - Car TN 09 AB 1234'), findsOneWidget);

    await tester.tap(find.text('Vehicle details'));
    await tester.pumpAndSettle();

    expect(find.text('TN 09 AB 1234'), findsOneWidget);
    expect(find.text('Honda City'), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
    expect(find.text('TN 10 CD 5678'), findsOneWidget);
    expect(find.text('Yamaha R15'), findsOneWidget);

    await tester.tap(find.text('Yamaha R15'));
    await tester.pumpAndSettle();

    expect(find.text('Registration number'), findsOneWidget);
    expect(find.text('TN 10 CD 5678'), findsOneWidget);
    expect(find.text('Yamaha'), findsOneWidget);
    expect(find.text('R15'), findsOneWidget);
  });

  testWidgets('vehicle details long press sets primary and deletes vehicle', (
    tester,
  ) async {
    final router = _router();
    final vehicleRepository = _FakeProfileVehicleRepository([
      const ProfileVehicle(
        id: 'vehicle-car',
        userId: 'user-1',
        type: 'car',
        registration: 'TN09AB1234',
        make: 'Honda',
        model: 'City',
        isPrimary: true,
      ),
      const ProfileVehicle(
        id: 'vehicle-bike',
        userId: 'user-1',
        type: 'bike',
        registration: 'TN10CD5678',
        make: 'Yamaha',
        model: 'R15',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _FakeAuthController(
              _authenticatedState(
                intent: 'park',
                setupStep: 'complete',
                vehicleMake: 'Honda',
                vehicleModel: 'City',
                vehicleRegistration: 'TN09AB1234',
                vehicleType: 'car',
              ),
            ),
          ),
          profileVehicleRepositoryProvider.overrideWithValue(vehicleRepository),
          userSetupRepositoryProvider.overrideWithValue(
            _FakeUserSetupRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vehicle details'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Yamaha R15'));
    await tester.pumpAndSettle();

    expect(find.text('Set as primary'), findsOneWidget);
    expect(find.text('Delete vehicle'), findsOneWidget);

    await tester.tap(find.text('Set as primary'));
    await tester.pumpAndSettle();

    expect(vehicleRepository.primaryVehicleId, 'vehicle-bike');
    expect(find.text('Primary vehicle updated'), findsOneWidget);

    await tester.longPress(find.text('Honda City'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete vehicle'));
    await tester.pumpAndSettle();

    expect(vehicleRepository.deletedVehicleIds, contains('vehicle-car'));
    expect(find.text('Honda City'), findsNothing);
    expect(find.text('Vehicle deleted'), findsOneWidget);
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
        path: '/profile/vehicle-details',
        builder: (_, _) => const VehicleDetailsScreen(),
      ),
      GoRoute(
        path: '/profile/vehicle-details/add',
        builder: (_, _) => const VehicleDetailsFormScreen(
          key: ValueKey('vehicle-details-add-test'),
        ),
      ),
      GoRoute(
        path: '/profile/vehicle-details/:vehicleId',
        builder: (_, state) => VehicleDetailsFormScreen(
          key: ValueKey(
            'vehicle-details-${state.pathParameters['vehicleId']}-test',
          ),
          vehicleId: state.pathParameters['vehicleId'],
        ),
      ),
      GoRoute(
        path: '/setup/host-basics',
        builder: (_, state) => HostSpaceBasicsScreen(
          createNew: state.uri.queryParameters['new'] == '1',
          instantLaunch: state.uri.queryParameters['launch'] == 'instant',
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

class _FakeProfileVehicleRepository extends ProfileVehicleRepository {
  _FakeProfileVehicleRepository(List<ProfileVehicle> vehicles)
    : _vehicles = [...vehicles];

  final List<String> deletedVehicleIds = [];
  String? primaryVehicleId;
  List<ProfileVehicle> _vehicles;

  @override
  Future<List<ProfileVehicle>> loadVehicles({
    required List<ProfileVehicle> fallback,
    required String? userId,
  }) async {
    return _vehicles;
  }

  @override
  Future<ProfileVehicle> setPrimaryVehicle(ProfileVehicle vehicle) async {
    primaryVehicleId = vehicle.id;
    _vehicles = [
      for (final saved in _vehicles)
        _copyVehicle(saved, isPrimary: saved.id == vehicle.id),
    ];
    return _vehicles.firstWhere((saved) => saved.id == vehicle.id);
  }

  @override
  Future<ProfileVehicle?> deleteVehicle(ProfileVehicle vehicle) async {
    final deleted = _vehicles.firstWhere((saved) => saved.id == vehicle.id);
    deletedVehicleIds.add(vehicle.id);
    _vehicles = [
      for (final saved in _vehicles)
        if (saved.id != vehicle.id) saved,
    ];
    if (!deleted.isPrimary || _vehicles.isEmpty) return null;
    return setPrimaryVehicle(_vehicles.first);
  }

  ProfileVehicle _copyVehicle(
    ProfileVehicle vehicle, {
    required bool isPrimary,
  }) {
    return ProfileVehicle(
      id: vehicle.id,
      userId: vehicle.userId,
      type: vehicle.type,
      registration: vehicle.registration,
      make: vehicle.make,
      model: vehicle.model,
      isPrimary: isPrimary,
      createdAt: vehicle.createdAt,
      updatedAt: vehicle.updatedAt,
    );
  }
}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._initial);

  final AuthState _initial;

  @override
  Future<AuthState> build() async => _initial;
}

AuthState _authenticatedState({
  String? hostParkingDraftId,
  String? intent,
  String? setupDraftId,
  String setupStep = 'host_basics',
  String? vehicleMake,
  String? vehicleModel,
  String? vehicleRegistration,
  String? vehicleType,
}) {
  return AuthState(
    status: AuthStatus.authenticated,
    user: const AppUser(id: 'user-1', email: 'host@example.com'),
    profile: UserProfile(
      id: 'user-1',
      email: 'host@example.com',
      fullName: 'Test Host',
      hostParkingDraftId: hostParkingDraftId,
      intent: intent,
      setupDraftId: setupDraftId,
      setupStep: setupStep,
      vehicleMake: vehicleMake,
      vehicleModel: vehicleModel,
      vehicleRegistration: vehicleRegistration,
      vehicleType: vehicleType,
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
  Future<void>? resumeLookupBarrier;
  HostBasicsDraftUpdate? savedBasics;
  bool? savedVehicleCreateNew;
  String? savedVehicleId;
  String? savedVehicleMake;
  String? savedVehicleModel;
  String? savedVehicleRegistration;
  String? savedVehicleType;
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
    await resumeLookupBarrier;
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
  Future<UserSetupState> saveVehicleDetails({
    bool createNew = false,
    String? previousVehicleRegistration,
    String? vehicleId,
    String? vehicleMake,
    String? vehicleModel,
    required String vehicleRegistration,
    required String vehicleType,
  }) async {
    savedVehicleCreateNew = createNew;
    savedVehicleId = vehicleId;
    savedVehicleMake = vehicleMake;
    savedVehicleModel = vehicleModel;
    savedVehicleRegistration = vehicleRegistration;
    savedVehicleType = vehicleType;
    return const UserSetupState(intent: 'park', step: 'complete');
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
