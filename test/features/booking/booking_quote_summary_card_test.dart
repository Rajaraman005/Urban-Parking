import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/features/booking/domain/booking_quote.dart';
import 'package:urban_parking/features/booking/presentation/widgets/booking_quote_summary_card.dart';

void main() {
  testWidgets('gst info badge explains the GST calculation on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingQuoteSummaryCard(
            durationLabel: '12 hours',
            subtotalBreakdownLabel: '12 x ₹50/hr',
            windowLabel: 'Wed, 13 May 9:00 AM to 9:00 PM',
            quote: BookingQuote(
              spotId: 'spot-1',
              startAt: _startAt,
              endAt: _endAt,
              subtotal: 600,
              platformFee: 90,
              taxes: 16,
              total: 706,
              currency: 'INR',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('gst-info-badge')));
    await tester.pumpAndSettle();

    expect(
      find.text('GST is calculated on\nthe platform fee only.'),
      findsOneWidget,
    );
  });
}

final _startAt = DateTime(2026, 5, 13, 9);
final _endAt = DateTime(2026, 5, 13, 21);
