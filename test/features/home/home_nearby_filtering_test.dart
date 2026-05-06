import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/features/home/presentation/home_nearby_filtering.dart';

void main() {
  test('bike filter keeps bike and shared spaces only', () {
    final items = [
      _parkingItem(
        id: 'bike-only',
        title: 'Bike bay',
        entity: const {'vehicleFit': 'bike'},
      ),
      _parkingItem(
        id: 'both',
        title: 'Shared parking',
        entity: const {'vehicleFit': 'both'},
      ),
      _parkingItem(
        id: 'car-only',
        title: 'Car bay',
        entity: const {'vehicleFit': 'car'},
      ),
    ];

    final results = filterHomeNearbyItems(items, HomeNearbyVehicleFilter.bike);

    expect(results.map((item) => item.id), ['bike-only', 'both']);
  });

  test('car filter uses structured data first and legacy fallback second', () {
    final items = [
      _parkingItem(
        id: 'car-only',
        title: 'Sedan parking',
        entity: const {'vehicleFit': 'car'},
      ),
      _parkingItem(
        id: 'generic',
        title: 'Covered parking',
        entity: const <String, Object?>{},
      ),
      _parkingItem(
        id: 'bike-only',
        title: 'Two wheeler stand',
        entity: const {
          'amenities': ['twoWheeler'],
        },
      ),
    ];

    final results = filterHomeNearbyItems(items, HomeNearbyVehicleFilter.car);

    expect(results.map((item) => item.id), ['car-only', 'generic']);
  });

  test('home filter sorting keeps low price before shorter distance', () {
    final items = [
      _parkingItem(id: 'near-expensive', title: 'Near', price: 90, distance: 1),
      _parkingItem(id: 'cheap', title: 'Cheap', price: 35, distance: 4),
      _parkingItem(
        id: 'no-price',
        title: 'No price',
        price: null,
        distance: 0.2,
      ),
    ];

    final results = applyHomeNearbyFilters(
      items,
      filters: const HomeNearbyFilterSelection(
        sort: HomeNearbySortOption.lowPrice,
      ),
      vehicleFilter: null,
    );

    expect(results.map((item) => item.id), [
      'cheap',
      'near-expensive',
      'no-price',
    ]);
  });

  test(
    'home quick filters match covered, ev charging, and security metadata',
    () {
      final items = [
        _parkingItem(
          id: 'covered-secure',
          title: 'Covered parking',
          entity: const {
            'amenities': ['Covered', 'CCTV'],
          },
        ),
        _parkingItem(
          id: 'covered-only',
          title: 'Basement parking',
          entity: const {
            'amenities': ['Covered'],
          },
        ),
        _parkingItem(
          id: 'ev',
          title: 'EV charging bay',
          entity: const {
            'amenities': ['EV charging'],
          },
        ),
      ];

      final secureCovered = applyHomeNearbyFilters(
        items,
        filters: const HomeNearbyFilterSelection(
          quickFilters: {
            HomeNearbyQuickFilter.covered,
            HomeNearbyQuickFilter.security,
          },
        ),
        vehicleFilter: null,
      );
      final ev = applyHomeNearbyFilters(
        items,
        filters: const HomeNearbyFilterSelection(
          quickFilters: {HomeNearbyQuickFilter.evCharging},
        ),
        vehicleFilter: null,
      );

      expect(secureCovered.map((item) => item.id), ['covered-secure']);
      expect(ev.map((item) => item.id), ['ev']);
    },
  );

  test('home vehicle and quick filters combine on the nearby list', () {
    final items = [
      _parkingItem(
        id: 'bike-covered',
        title: 'Covered two wheeler stand',
        entity: const {
          'vehicleFit': 'bike',
          'amenities': ['covered'],
        },
      ),
      _parkingItem(
        id: 'car-covered',
        title: 'Covered car parking',
        entity: const {
          'vehicleFit': 'car',
          'amenities': ['covered'],
        },
      ),
    ];

    final results = applyHomeNearbyFilters(
      items,
      filters: const HomeNearbyFilterSelection(
        quickFilters: {HomeNearbyQuickFilter.covered},
      ),
      vehicleFilter: HomeNearbyVehicleFilter.bike,
    );

    expect(results.map((item) => item.id), ['bike-covered']);
  });
}

GeoDiscoveryEntity<Map<String, Object?>> _parkingItem({
  double distance = 1,
  Map<String, Object?> entity = const <String, Object?>{},
  required String id,
  num? price = 50,
  num? rating = 4.7,
  AvailabilityStatus status = AvailabilityStatus.available,
  required String title,
}) {
  return GeoDiscoveryEntity<Map<String, Object?>>(
    availabilityStatus: status,
    currency: 'INR',
    distanceKm: distance,
    entity: {'title': title, ...entity},
    id: id,
    imageUrl: null,
    location: const GeoPoint(latitude: 13.08, longitude: 80.27),
    price: price,
    rating: rating,
    serviceType: ServiceType.parking,
    title: title,
  );
}
