import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/features/parking/presentation/widgets/availability_date_range_field.dart';

void main() {
  testWidgets('opening the availability date picker clears text input focus', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(focusNode: focusNode),
              const SizedBox(height: 16),
              AvailabilityDateRangeField(
                fromDate: DateTime(2026, 5, 2),
                onRangeChanged: (_) {},
                onSkipWeekendsChanged: (_) {},
                skipWeekends: false,
                toDate: DateTime(2026, 5, 31),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Date range'));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });
}
