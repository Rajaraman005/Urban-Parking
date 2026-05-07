import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/core/utils/geo_discovery/geo_types.dart';
import 'package:urban_parking/features/host_parking/domain/host_parking_draft.dart';

void main() {
  test('calculates completion from basics, pricing, and photos', () {
    final draft = HostParkingDraft(
      id: 'draft-1',
      status: 'draft',
      currentStep: 'host_review',
      version: 3,
      completionPercent: 0,
      data: HostParkingDraftData(
        basics: const HostParkingBasicsData(
          accessInstructions:
              'Covered parking near the entrance with easy access and lighting.',
          address: '12 Main Road, Chennai',
          addressConfidence: 0.9,
          addressProvider: 'manual',
          city: 'Chennai',
          locality: 'Anna Nagar',
          location: GeoPoint(latitude: 13.0827, longitude: 80.2707),
          parkingType: 'covered',
          postalCode: '600001',
          stateName: 'Tamil Nadu',
          title: 'Covered car parking',
          vehicleFit: 'car',
        ),
        pricing: HostParkingPricingData(
          availableFromDate: DateTime(2026, 5, 7),
          availableToDate: DateTime(2026, 6, 7),
          dailyEndMinute: 20 * 60,
          dailyStartMinute: 8 * 60,
          hourlyPrice: 80,
          slotsCount: 1,
        ),
      ),
      photos: const [
        HostParkingDraftPhoto(
          id: 'photo-1',
          publicId: 'photo-1',
          secureUrl: 'https://example.com/1.jpg',
          sortOrder: 0,
        ),
        HostParkingDraftPhoto(
          id: 'photo-2',
          publicId: 'photo-2',
          secureUrl: 'https://example.com/2.jpg',
          sortOrder: 1,
        ),
      ],
    );

    expect(calculateHostParkingCompletion(draft), 100);
  });

  test('detects overlapping conflict field paths deterministically', () {
    expect(
      conflictingFieldPaths(
        const ['basics.title', 'pricing.hourlyPrice'],
        const ['photos.order', 'basics.title'],
      ),
      const ['basics.title'],
    );
  });

  test('parses draft aggregate payload into typed domain model', () {
    final draft = HostParkingDraft.fromJson({
      'id': 'draft-1',
      'status': 'draft',
      'current_step': 'host_pricing',
      'version': 2,
      'completion_percent': 35,
      'draft_data': {
        'basics': {
          'title': 'Car parking',
          'address': '12 Main Road, Chennai',
          'city': 'Chennai',
          'locality': 'Anna Nagar',
          'postalCode': '600001',
          'location': {'latitude': 13.0827, 'longitude': 80.2707},
          'parkingType': 'open',
          'vehicleFit': 'car',
        },
      },
      'parking_listing_draft_photos': [
        {
          'id': 'photo-2',
          'public_id': 'photo-2',
          'secure_url': 'https://example.com/2.jpg',
          'sort_order': 1,
        },
        {
          'id': 'photo-1',
          'public_id': 'photo-1',
          'secure_url': 'https://example.com/1.jpg',
          'sort_order': 0,
        },
      ],
    });

    expect(draft.currentStep, 'host_pricing');
    expect(draft.data.basics.title, 'Car parking');
    expect(draft.photos.map((photo) => photo.id), ['photo-1', 'photo-2']);
  });
}
