import 'package:flutter/material.dart';

enum BookingVehicleKind { bike, car }

extension BookingVehicleKindX on BookingVehicleKind {
  IconData get icon {
    switch (this) {
      case BookingVehicleKind.bike:
        return Icons.two_wheeler_rounded;
      case BookingVehicleKind.car:
        return Icons.directions_car_filled_rounded;
    }
  }

  String get label {
    switch (this) {
      case BookingVehicleKind.bike:
        return 'Bike';
      case BookingVehicleKind.car:
        return 'Car';
    }
  }
}

class BookingVehicleToggle extends StatelessWidget {
  const BookingVehicleToggle({
    required this.onChanged,
    required this.selectedKind,
    super.key,
  });

  final ValueChanged<BookingVehicleKind> onChanged;
  final BookingVehicleKind selectedKind;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          height: 58,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const outerPadding = 4.0;
              final knobHeight = constraints.maxHeight - (outerPadding * 2);
              final knobWidth = (constraints.maxWidth - (outerPadding * 2)) / 2;

              return Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(outerPadding),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: selectedKind == BookingVehicleKind.bike
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            key: const ValueKey('vehicle-toggle-thumb'),
                            width: knobWidth,
                            height: knobHeight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _VehicleToggleSegment(
                          kind: BookingVehicleKind.bike,
                          selected: selectedKind == BookingVehicleKind.bike,
                          onTap: () => onChanged(BookingVehicleKind.bike),
                        ),
                      ),
                      Expanded(
                        child: _VehicleToggleSegment(
                          kind: BookingVehicleKind.car,
                          selected: selectedKind == BookingVehicleKind.car,
                          onTap: () => onChanged(BookingVehicleKind.car),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VehicleToggleSegment extends StatelessWidget {
  const _VehicleToggleSegment({
    required this.kind,
    required this.onTap,
    required this.selected,
  });

  final BookingVehicleKind kind;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected ? Colors.white : Colors.black;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('vehicle-toggle-${kind.name}'),
          onTap: onTap,
          child: Ink(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(kind.icon, color: foregroundColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    kind.label,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
