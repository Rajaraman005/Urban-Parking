import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/tab_placeholder_screen.dart';
import '../../auth/presentation/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;

    return TabPlaceholderScreen(
      icon: Icons.person_outline,
      sectionLabel: 'Profile',
      title: auth?.profile?.fullName == null
          ? 'One place for your account and hosting tools'
          : 'Hi, ${auth!.profile!.fullName}',
      subtitle:
          'A clean account home for personal settings, hosting context, and everything that belongs to the user rather than the trip.',
      highlights: const ['Account', 'Hosting', 'Payouts'],
      footerTitle: 'Account essentials live here',
      footerBody:
          'Profile is prepared for account settings, host tools, payout details, and the parts of the app users expect to revisit often.',
    );
  }
}
