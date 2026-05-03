import 'dart:math' as math;

import 'geo_types.dart';

const _earthRadiusKm = 6371.0088;

double _toRadians(double degrees) => degrees * math.pi / 180;

double haversineDistanceKm(GeoPoint from, GeoPoint to) {
  final dLat = _toRadians(to.latitude - from.latitude);
  final dLon = _toRadians(to.longitude - from.longitude);
  final lat1 = _toRadians(from.latitude);
  final lat2 = _toRadians(to.latitude);

  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);

  return 2 * _earthRadiusKm * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double distanceMeters(GeoPoint from, GeoPoint to) =>
    haversineDistanceKm(from, to) * 1000;

double roundDistanceKm(double distanceKm) =>
    (distanceKm * 100).roundToDouble() / 100;
