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
    avatarUrl: displayProfileAvatarUrl(profile),
    displayEmail: email,
    displayName: _displayName(auth, email),
    isSignedIn: auth?.isAuthenticated ?? false,
    phone: _clean(profile?.phone),
    profile: profile,
  );
}

String? displayProfileAvatarUrl(UserProfile? profile) {
  final url = _clean(profile?.avatarUrl);
  if (url == null) return null;

  final publicId = _clean(profile?.avatarPublicId);
  if (publicId != null) return url;

  return _isProviderSeededAvatar(url) ? null : url;
}

String profileInitials(String? value, {String fallback = 'UP'}) {
  final compact = (value ?? '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (compact.length >= 2) {
    return compact.substring(0, 2).toUpperCase();
  }
  if (compact.length == 1) {
    return compact.toUpperCase();
  }
  return fallback;
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

  return 'Lotzi member';
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

  return 'guest@lotzi.in';
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _isProviderSeededAvatar(String url) {
  final uri = Uri.tryParse(url);
  final host = uri?.host.toLowerCase() ?? url.toLowerCase();
  return host.contains('googleusercontent.com') ||
      host.contains('ggpht.com') ||
      host.contains('googleapis.com');
}
