import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:urban_parking/shared/widgets/product_card.dart';

void main() {
  testWidgets('ProductCard renders a swipeable carousel for multiple photos', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductCard(
            imageUrl: 'https://example.com/photo-1.jpg',
            imageUrls: [
              'https://example.com/photo-1.jpg',
              'https://example.com/photo-2.jpg',
              'https://example.com/photo-3.jpg',
            ],
            title: 'Bike Parking',
            subtitle: 'Thamari Street',
          ),
        ),
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(3));

    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller;
    expect(controller, isNotNull);
    expect(controller!.page, 0);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.page, closeTo(1, 0.01));
  });
}
