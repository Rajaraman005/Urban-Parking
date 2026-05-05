import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/shared/widgets/listing_details_page.dart';

void main() {
  testWidgets('tapping the hero image opens the fullscreen viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListingDetailsPage(
          address: 'Ambasamudram, Tirunelveli, Tamil Nadu',
          description: 'Verified parking space with secure access.',
          heroImageUrls: const [
            'https://example.com/parking-1.jpg',
            'https://example.com/parking-2.jpg',
          ],
          onBack: () {},
          onPrimaryAction: () {},
          priceText: '₹50/hr',
          primaryActionLabel: 'Book Now',
          stats: const [
            ListingDetailStat('1 Garage'),
            ListingDetailStat('Hourly'),
          ],
          title: 'Car parking',
        ),
      ),
    );

    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(AspectRatio).first));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets);
  });

  testWidgets('multi-image hero keeps the page view in place', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListingDetailsPage(
          address: 'Ambasamudram, Tirunelveli, Tamil Nadu',
          description: 'Verified parking space with secure access.',
          heroImageUrls: const [
            'https://example.com/parking-1.jpg',
            'https://example.com/parking-2.jpg',
          ],
          onBack: () {},
          onPrimaryAction: () {},
          priceText: 'Rs50/hr',
          primaryActionLabel: 'Book Now',
          stats: const [
            ListingDetailStat('1 Garage'),
            ListingDetailStat('Hourly'),
          ],
          title: 'Car parking',
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(2));
  });
}
