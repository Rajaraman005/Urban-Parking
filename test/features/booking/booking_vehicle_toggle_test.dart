import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/features/booking/presentation/widgets/booking_vehicle_toggle.dart';

void main() {
  testWidgets('vehicle toggle switches between bike and car', (tester) async {
    var selectedKind = BookingVehicleKind.car;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Center(
                child: BookingVehicleToggle(
                  selectedKind: selectedKind,
                  onChanged: (kind) {
                    setState(() {
                      selectedKind = kind;
                    });
                  },
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(selectedKind, BookingVehicleKind.car);

    await tester.tap(find.byKey(const ValueKey('vehicle-toggle-bike')));
    await tester.pumpAndSettle();
    expect(selectedKind, BookingVehicleKind.bike);

    await tester.tap(find.byKey(const ValueKey('vehicle-toggle-car')));
    await tester.pumpAndSettle();
    expect(selectedKind, BookingVehicleKind.car);
  });

  testWidgets('selected segment keeps a visible thumb background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: BookingVehicleToggle(
              selectedKind: BookingVehicleKind.car,
              onChanged: _noopVehicleChange,
            ),
          ),
        ),
      ),
    );

    final thumbSize = tester.getSize(
      find.byKey(const ValueKey('vehicle-toggle-thumb')),
    );
    expect(thumbSize.height, greaterThan(0));
    expect(thumbSize.width, greaterThan(0));
  });
}

void _noopVehicleChange(BookingVehicleKind _) {}
