import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/formatters.dart';
import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/network_image_tile.dart';
import '../../../shared/widgets/state_view.dart';
import 'booking_controller.dart';

class BookingScreen extends ConsumerWidget {
  const BookingScreen({required this.spotId, super.key});

  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingControllerProvider(spotId));

    return AppScreen(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Booking'),
      ),
      child: booking.when(
        loading: () => const StateView(
          title: 'Preparing booking',
          body: 'Loading space and quote details.',
          isLoading: true,
        ),
        error: (error, _) => StateView(
          title: 'Could not load booking',
          body: error.toString(),
          actionLabel: 'Back to search',
          onAction: () => context.go('/search'),
        ),
        data: (state) {
          final spot = state.spot;
          final quote = state.quote;
          final timeFormat = DateFormat('EEE, h:mm a');

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              NetworkImageTile(url: spot.imageUrl, height: 220),
              const SizedBox(height: 18),
              Text(
                spot.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                spot.address,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final amenity in spot.amenities.take(4))
                    Chip(label: Text(amenity.name)),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking summary',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${timeFormat.format(quote.startAt)} to ${timeFormat.format(quote.endAt)}',
                      ),
                      const SizedBox(height: 16),
                      _Row(
                        label:
                            '${formatMoney(spot.price, spot.currency)} / ${cadenceLabel(spot.cadence)}',
                        value: formatMoney(quote.subtotal, quote.currency),
                      ),
                      _Row(
                        label: 'Platform fee',
                        value: formatMoney(quote.platformFee, quote.currency),
                      ),
                      _Row(
                        label: 'GST',
                        value: formatMoney(quote.taxes, quote.currency),
                      ),
                      const Divider(height: 24),
                      _Row(
                        label: 'Total',
                        value: formatMoney(quote.total, quote.currency),
                        strong: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Reserve slot'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
