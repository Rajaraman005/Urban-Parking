import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_screen.dart';

class PasswordResetScreen extends StatelessWidget {
  const PasswordResetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      appBar: AppBar(title: const Text('Reset password')),
      child: ListView(
        children: [
          const SizedBox(height: 40),
          Text(
            'Password recovery',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email in the auth screen and use Supabase reset links for production. This route is ready for the full reset form.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/auth?mode=login'),
            child: const Text('Back to login'),
          ),
        ],
      ),
    );
  }
}
