import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_controller.dart';

final currentProfileDisplayProvider = Provider<ProfileDisplay>((ref) {
  final auth = ref.watch(authControllerProvider).value;
  return profileDisplayFor(auth);
});

class ProfileDisplay {
  const ProfileDisplay({
    required this.displayEmail,
    required this.displayName,
    required this.isSignedIn,
    this.avatarUrl,
    this.phone,
    this.profile,
  });

  final String? avatarUrl;
  final String displayEmail;
  final String displayName;
  final bool isSignedIn;
  final String? phone;
  final UserProfile? profile;
}

ProfileDisplay profileDisplayFor(AuthState? auth) {
  final profile = auth?.profile;
  final email = _displayEmail(auth);
  return ProfileDisplay(
    avatarUrl: _clean(profile?.avatarUrl),
    displayEmail: email,
    displayName: _displayName(auth, email),
    isSignedIn: auth?.isAuthenticated ?? false,
    phone: _clean(profile?.phone),
    profile: profile,
  );
}

String _displayName(AuthState? auth, String email) {
  final name = _clean(auth?.profile?.fullName);
  if (name != null) {
    return name;
  }

  final localPart = email.split('@').first.trim();
  if (localPart.isNotEmpty && localPart != 'guest') {
    return localPart;
  }

  return 'Urban Parker';
}

String _displayEmail(AuthState? auth) {
  final profileEmail = _clean(auth?.profile?.email);
  if (profileEmail != null) {
    return profileEmail;
  }

  final userEmail = _clean(auth?.user?.email);
  if (userEmail != null) {
    return userEmail;
  }

  return 'guest@urbanparking.app';
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
