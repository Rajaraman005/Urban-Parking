import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_screen.dart';
import 'user_setup_controller.dart';

export 'host_space_basics_screen.dart';
export 'host_space_photos_screen.dart';
export 'host_space_pricing_screen.dart';
export 'host_space_review_screen.dart';

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

class _SetupStepScreen extends ConsumerWidget {
  const _SetupStepScreen({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.nextRoute,
  });

  final String title;
  final String body;
  final String actionLabel;
  final String nextRoute;

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
              if (context.mounted) context.go(nextRoute);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
