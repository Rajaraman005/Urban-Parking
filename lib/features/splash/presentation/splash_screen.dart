import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/telemetry.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final minimumSplash = Future<void>.delayed(
      const Duration(milliseconds: 750),
    );
    final authState = await ref.read(authControllerProvider.future);
    await minimumSplash;
    if (!mounted) return;
    telemetry.event(TelemetryEvent.appBootCompleted);

    if (authState.status == AuthStatus.authenticated) {
      final profile = authState.profile;
      if (profile?.hasCompletedOnboarding == true) {
        context.go('/home');
      } else {
        context.go(_setupRouteFor(profile));
      }
      return;
    }
    context.go('/onboarding');
  }

  String _setupRouteFor(UserProfile? profile) {
    switch (profile?.setupStep) {
      case 'profile':
        return '/setup/profile';
      case 'host_basics':
        return '/setup/host-basics';
      case 'host_pricing':
        return '/setup/host-pricing';
      case 'host_photos':
        return '/setup/host-photos';
      case 'host_review':
        return '/setup/host-review';
      default:
        return '/setup/intent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('src/assets/logo-mark.png', width: 144, height: 144),
            const SizedBox(height: 16),
            Text(
              'Urban Parking',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
