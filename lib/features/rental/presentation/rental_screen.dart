import 'package:flutter/material.dart';

import '../../../shared/widgets/tab_placeholder_screen.dart';

class RentalScreen extends StatelessWidget {
  const RentalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderScreen(
      icon: Icons.directions_car_outlined,
      sectionLabel: 'Rental',
      title: 'Rental plans that feel easy to manage',
      subtitle:
          'A focused place for renters to manage recurring needs, compare plans, and get back to the right space quickly.',
      highlights: ['Daily', 'Monthly', 'Commute'],
      footerTitle: 'Built for repeat parking',
      footerBody:
          'This tab is ready for renter-first discovery flows like recent bookings, favorites, and repeat parking plans.',
    );
  }
}
