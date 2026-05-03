import 'package:flutter/material.dart';

import '../../../shared/widgets/tab_placeholder_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderScreen(
      icon: Icons.auto_awesome_outlined,
      sectionLabel: 'Services',
      title: 'Useful services, kept close',
      subtitle:
          'Keep secondary tools together in one place so the core booking flow stays focused and quiet.',
      highlights: ['Support', 'Access help', 'Add-ons'],
      footerTitle: 'A place for service tools',
      footerBody:
          'This tab is reserved for add-on services like support, access help, and value-added experiences around every booking.',
    );
  }
}
