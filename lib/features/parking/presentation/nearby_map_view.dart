import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../config/geo_discovery_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/geo_discovery/geo_types.dart';

class NearbyMapView extends StatelessWidget {
  const NearbyMapView({required this.center, required this.items, super.key});

  final GeoPoint? center;
  final List<GeoDiscoveryEntity<Map<String, Object?>>> items;

  @override
  Widget build(BuildContext context) {
    final fallback = center ?? AppConstants.chennaiCenter;
    final visibleMarkers = items
        .take(GeoDiscoveryConfig.maxInitialMarkers)
        .map(
          (item) => Marker(
            markerId: MarkerId('${item.serviceType.apiValue}:${item.id}'),
            position: LatLng(item.location.latitude, item.location.longitude),
            infoWindow: InfoWindow(
              title: item.title,
              snippet: '${item.distanceKm.toStringAsFixed(1)} km away',
            ),
          ),
        )
        .toSet();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(fallback.latitude, fallback.longitude),
          zoom: 13,
        ),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        markers: visibleMarkers,
      ),
    );
  }
}
