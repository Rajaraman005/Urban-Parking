import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/formatters.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/listing_context_section.dart';
import '../../../shared/widgets/listing_details_page.dart';
import '../../../shared/widgets/state_view.dart';
import '../../../shared/widgets/urban_bottom_nav.dart';
import '../../parking/domain/parking_spot.dart';
import '../../profile/presentation/profile_display.dart';
import 'booking_controller.dart';

class BookingScreen extends ConsumerWidget {
  const BookingScreen({required this.spotId, super.key});

  final String spotId;
  static const _detailBottomNav = UrbanBottomNav(currentIndex: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spot = ref.watch(bookingSpotProvider(spotId));

    return spot.when(
      loading: () => const AppScreen(
        bottomNavigationBar: _detailBottomNav,
        child: StateView(
          title: 'Loading property',
          body: 'Preparing space details.',
          isLoading: true,
        ),
      ),
      error: (error, _) => AppScreen(
        bottomNavigationBar: _detailBottomNav,
        child: StateView(
          title: 'Could not load property',
          body: error.toString(),
          actionLabel: 'Back to search',
          onAction: () => context.go('/search'),
        ),
      ),
      data: (spot) => _PropertyDetailsContent(
        onBack: () => _close(context),
        onBookNow: () => _openBookingSchedule(context, ref),
        spot: spot,
      ),
    );
  }

  void _close(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go('/home');
  }

  void _openBookingSchedule(BuildContext context, WidgetRef ref) {
    ref.invalidate(bookingSpotProvider(spotId));
    context.push('/booking/$spotId/schedule');
  }
}

class _PropertyDetailsContent extends ConsumerWidget {
  const _PropertyDetailsContent({
    required this.onBack,
    required this.onBookNow,
    required this.spot,
  });

  final VoidCallback onBack;
  final VoidCallback onBookNow;
  final ParkingSpot spot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileDisplay = spot.isHostedByCurrentUser
        ? ref.watch(currentProfileDisplayProvider)
        : null;
    final hostName =
        profileDisplay?.displayName ?? spot.hostName ?? 'Lotzi Host';
    final hostAvatarUrl = profileDisplay?.avatarUrl ?? spot.hostAvatarUrl;
    final hostPhone = profileDisplay?.phone ?? spot.hostPhone;

    return ListingDetailsPage(
      address: spot.address.isEmpty ? spot.locality : spot.address,
      description: _descriptionFor(spot),
      heroImageUrls: spot.imageUrls,
      listingLabel: 'For Rent',
      onBack: onBack,
      onFavorite: () {},
      onShare: null,
      onPrimaryAction: onBookNow,
      bottomNavigationBar: BookingScreen._detailBottomNav,
      priceText: _priceTextFor(spot),
      primaryActionLabel: 'Book Now',
      ratingText: spot.rating > 0 ? spot.rating.toStringAsFixed(1) : '4.8',
      reviewText: spot.reviewCount > 0 ? '${spot.reviewCount} reviews' : null,
      sectionsBeforeDescription: [
        ListingContextSection(
          hostAvatarUrl: hostAvatarUrl,
          hostName: hostName,
          location: spot.location,
          onCallTap: _hostContactAction(
            context,
            phoneNumber: hostPhone,
            scheme: 'tel',
            unavailableMessage: 'Host phone number is not available yet.',
          ),
          onMessageTap: _hostContactAction(
            context,
            phoneNumber: hostPhone,
            scheme: 'sms',
            unavailableMessage: 'Host phone number is not available yet.',
          ),
        ),
      ],
      stats: _statsFor(spot),
      title: spot.title,
      topTitle: 'Property Details',
    );
  }

  List<ListingDetailStat> _statsFor(ParkingSpot spot) {
    final stats = <ListingDetailStat>[
      ListingDetailStat(
        '${spot.slotsAvailable} Garage',
        icon: Icons.local_parking_rounded,
      ),
      ListingDetailStat(
        _cadenceLabel(spot.cadence),
        icon: Icons.schedule_rounded,
      ),
    ];

    for (final amenity in spot.amenities.take(3)) {
      stats.add(
        ListingDetailStat(_amenityLabel(amenity), icon: _amenityIcon(amenity)),
      );
    }

    return stats.take(5).toList(growable: false);
  }

  String _amenityLabel(ParkingAmenity amenity) {
    switch (amenity) {
      case ParkingAmenity.covered:
        return 'Covered';
      case ParkingAmenity.security:
        return 'Security';
      case ParkingAmenity.evCharging:
        return 'EV Charging';
      case ParkingAmenity.cctv:
        return 'CCTV';
      case ParkingAmenity.valet:
        return 'Valet';
      case ParkingAmenity.twoWheeler:
        return '2 Wheeler';
    }
  }

  IconData _amenityIcon(ParkingAmenity amenity) {
    switch (amenity) {
      case ParkingAmenity.covered:
        return Icons.roofing_rounded;
      case ParkingAmenity.security:
        return Icons.verified_user_outlined;
      case ParkingAmenity.evCharging:
        return Icons.ev_station_rounded;
      case ParkingAmenity.cctv:
        return Icons.videocam_outlined;
      case ParkingAmenity.valet:
        return Icons.key_rounded;
      case ParkingAmenity.twoWheeler:
        return Icons.two_wheeler_rounded;
    }
  }

  String _cadenceLabel(BookingCadence cadence) {
    switch (cadence) {
      case BookingCadence.hourly:
        return 'Hourly';
      case BookingCadence.daily:
        return 'Daily';
      case BookingCadence.monthly:
        return 'Monthly';
    }
  }

  String _priceTextFor(ParkingSpot spot) {
    final cadence = switch (spot.cadence) {
      BookingCadence.hourly => 'hr',
      BookingCadence.daily => 'day',
      BookingCadence.monthly => 'mo',
    };
    return '${formatMoney(spot.price, spot.currency)}/$cadence';
  }

  String _descriptionFor(ParkingSpot spot) {
    final description = spot.description?.trim();
    if (description != null && description.isNotEmpty) {
      return description;
    }

    final locality = spot.locality.isEmpty ? 'this location' : spot.locality;
    return 'Verified parking space in $locality with secure access, clear host details, and a clean location profile for quick decisions.';
  }

  VoidCallback? _hostContactAction(
    BuildContext context, {
    required String? phoneNumber,
    required String scheme,
    required String unavailableMessage,
  }) {
    final normalizedPhone = _normalizedPhoneNumber(phoneNumber);
    if (normalizedPhone == null) return null;

    return () => _launchHostContact(
      context,
      phoneNumber: normalizedPhone,
      scheme: scheme,
      unavailableMessage: unavailableMessage,
    );
  }

  Future<void> _launchHostContact(
    BuildContext context, {
    required String phoneNumber,
    required String scheme,
    required String unavailableMessage,
  }) async {
    final uri = Uri(scheme: scheme, path: phoneNumber);
    final canOpen = await canLaunchUrl(uri);
    if (canOpen) {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(unavailableMessage)));
  }

  String? _normalizedPhoneNumber(String? rawValue) {
    if (rawValue == null) return null;
    final cleaned = rawValue.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }
}
