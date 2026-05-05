import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/shared/widgets/fullscreen_image_viewer_page.dart';

void main() {
  testWidgets('viewer starts at the requested image and shows controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenImageViewerPage(
          imageUrls: [
            'https://example.com/parking-1.jpg',
            'https://example.com/parking-2.jpg',
            'https://example.com/parking-3.jpg',
          ],
          initialIndex: 1,
        ),
      ),
    );

    await tester.pump();

    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });
}
