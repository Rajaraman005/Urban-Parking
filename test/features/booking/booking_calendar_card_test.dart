import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/features/booking/presentation/widgets/booking_calendar_card.dart';

void main() {
  testWidgets('single-month availability disables previous and next month', (
    tester,
  ) async {
    final availableDays = List.generate(
      27,
      (index) => DateTime(2026, 5, index + 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: BookingCalendarCard(
                availableDays: availableDays,
                focusedDay: DateTime(2026, 5, 5),
                onFocusedDayChanged: (_) {},
                onDaySelected: (_) {},
                selectedDay: DateTime(2026, 5, 5),
              ),
            ),
          ),
        ),
      ),
    );

    final previousButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_left_rounded),
        matching: find.byType(IconButton),
      ),
    );
    final nextButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_right_rounded),
        matching: find.byType(IconButton),
      ),
    );

    expect(previousButton.onPressed, isNull);
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('multi-month availability allows month navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 360, child: _CalendarHarness())),
        ),
      ),
    );

    expect(find.text('May 2026'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    expect(find.text('June 2026'), findsOneWidget);
  });
}

class _CalendarHarness extends StatefulWidget {
  const _CalendarHarness();

  @override
  State<_CalendarHarness> createState() => _CalendarHarnessState();
}

class _CalendarHarnessState extends State<_CalendarHarness> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  final List<DateTime> _availableDays = [
    DateTime(2026, 5, 30),
    DateTime(2026, 5, 31),
    DateTime(2026, 6, 1),
    DateTime(2026, 6, 2),
  ];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime(2026, 5, 30);
    _selectedDay = DateTime(2026, 5, 30);
  }

  @override
  Widget build(BuildContext context) {
    return BookingCalendarCard(
      availableDays: _availableDays,
      focusedDay: _focusedDay,
      onFocusedDayChanged: (day) {
        setState(() {
          _focusedDay = DateTime(day.year, day.month, day.day);
        });
      },
      onDaySelected: (day) {
        setState(() {
          _selectedDay = day;
          _focusedDay = DateTime(day.year, day.month, day.day);
        });
      },
      selectedDay: _selectedDay,
    );
  }
}
