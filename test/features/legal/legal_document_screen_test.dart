import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/features/legal/data/legal_documents.dart';
import 'package:urban_parking/features/legal/presentation/legal_document_screen.dart';

void main() {
  testWidgets('legal document uses readable consent-inspired typography', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalDocumentScreen(document: privacyPolicy)),
    );

    final paragraph = tester.widget<Text>(
      find
          .text(
            'This Privacy Policy applies to Urban Parking mobile apps, websites, support channels, booking flows, host listing flows, and related services.',
          )
          .first,
    );
    final sectionTitle = tester.widget<Text>(find.text('1. Scope').first);
    final effectiveDate = tester.widget<Text>(
      find.text('Effective 1 May 2026').first,
    );

    expect(paragraph.style?.fontWeight, FontWeight.w500);
    expect(paragraph.style?.height, 1.58);
    expect(sectionTitle.style?.fontWeight, FontWeight.w800);
    expect(effectiveDate.style?.fontWeight, FontWeight.w600);
    expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
  });
}
