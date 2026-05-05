import '../../../core/utils/geo_discovery/geo_types.dart';
import '../domain/parking_spot.dart';

class ParkingSpotCache {
  final _spotsById = <String, ParkingSpot>{};

  ParkingSpot? getById(String id) => _spotsById[id];

  void upsert(ParkingSpot spot) {
    if (spot.id.trim().isEmpty) return;
    _spotsById[spot.id] = spot;
  }

  void upsertMany(Iterable<ParkingSpot> spots) {
    for (final spot in spots) {
      upsert(spot);
    }
  }

  void upsertDiscoveryItems(
    Iterable<GeoDiscoveryEntity<Map<String, Object?>>> items,
  ) {
    for (final item in items) {
      if (item.serviceType != ServiceType.parking) continue;
      try {
        upsert(ParkingSpot.fromDiscoveryEntity(item));
      } catch (_) {
        // Ignore malformed rows so one bad marketplace item cannot break
        // navigation for the rest of the feed.
      }
    }
  }
}
