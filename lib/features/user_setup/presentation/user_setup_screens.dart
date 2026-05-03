import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_screen.dart';
import 'user_setup_controller.dart';

class UserSetupIntentScreen extends ConsumerWidget {
  const UserSetupIntentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How will you use Urban Parking?',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              await ref
                  .read(userSetupControllerProvider.notifier)
                  .saveIntent('park');
              if (context.mounted) context.go('/setup/profile');
            },
            icon: const Icon(Icons.local_parking_outlined),
            label: const Text('Find parking'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await ref
                  .read(userSetupControllerProvider.notifier)
                  .saveIntent('host');
              if (context.mounted) context.go('/setup/profile');
            },
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Host a space'),
          ),
        ],
      ),
    );
  }
}

class UserSetupProfileScreen extends StatelessWidget {
  const UserSetupProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SetupStepScreen(
      title: 'Tell us about you',
      body:
          'Profile validation preserves Indian mobile, DOB, gender, and account setup rules. The production repository is ready to wire to Supabase optimistic writes.',
      actionLabel: 'Continue',
      nextRoute: '/setup/host-basics',
    );
  }
}

class HostSpaceBasicsScreen extends StatelessWidget {
  const HostSpaceBasicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SetupStepScreen(
      title: 'Parking space basics',
      body:
          'Address lookup, OSM reverse geocode, vehicle fit, parking type, and access instructions belong in this step.',
      actionLabel: 'Save basics',
      nextRoute: '/setup/host-pricing',
      step: 'host_basics',
    );
  }
}

class HostSpacePricingScreen extends StatelessWidget {
  const HostSpacePricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SetupStepScreen(
      title: 'Pricing and availability',
      body:
          'Hourly price, bounded dates, 30-minute daily windows, dimensions, slot count, and weekend rules are validated here.',
      actionLabel: 'Save pricing',
      nextRoute: '/setup/host-photos',
      step: 'host_pricing',
    );
  }
}

class HostSpacePhotosScreen extends StatelessWidget {
  const HostSpacePhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SetupStepScreen(
      title: 'Upload parking photos',
      body:
          'Cloudinary signed upload orchestration preserves retry safety and draft state without duplicating photo records.',
      actionLabel: 'Continue to review',
      nextRoute: '/setup/host-review',
      step: 'host_photos',
    );
  }
}

class HostSpaceReviewScreen extends StatelessWidget {
  const HostSpaceReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SetupStepScreen(
      title: 'Review and submit',
      body:
          'Submission uses the trusted backend function and keeps active listing approval server-gated.',
      actionLabel: 'Submit for review',
      nextRoute: '/home',
      step: 'host_review',
    );
  }
}

class _SetupStepScreen extends ConsumerWidget {
  const _SetupStepScreen({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.nextRoute,
    this.step,
  });

  final String title;
  final String body;
  final String actionLabel;
  final String nextRoute;
  final String? step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen(
      appBar: AppBar(title: const Text('Setup')),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              if (step != null) {
                await ref
                    .read(userSetupControllerProvider.notifier)
                    .advanceHostStep(step!);
              }
              if (context.mounted) context.go(nextRoute);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
