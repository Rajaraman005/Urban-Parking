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
}

GeoDiscoveryEntity<Map<String, Object?>> _parkingItem({
  required Map<String, Object?> entity,
  required String id,
  required String title,
}) {
  return GeoDiscoveryEntity<Map<String, Object?>>(
    availabilityStatus: AvailabilityStatus.available,
    currency: 'INR',
    distanceKm: 1,
    entity: {
      'title': title,
      ...entity,
    },
    id: id,
    imageUrl: null,
    location: const GeoPoint(latitude: 13.08, longitude: 80.27),
    price: 50,
    rating: 4.7,
    serviceType: ServiceType.parking,
    title: title,
  );
}
