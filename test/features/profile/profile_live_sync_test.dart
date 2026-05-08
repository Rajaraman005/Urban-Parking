import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/features/auth/domain/auth_state.dart';
import 'package:urban_parking/features/profile/presentation/profile_display.dart';
import 'package:urban_parking/features/profile/presentation/profile_live_sync.dart';

void main() {
  test('profile display uses profile fields before auth fallbacks', () {
    final display = profileDisplayFor(
      const AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(id: 'user-1', email: 'auth@example.com'),
        profile: UserProfile(
          id: 'user-1',
          fullName: 'Fresh User',
          email: 'profile@example.com',
          avatarUrl: 'https://example.com/avatar.jpg',
          phone: '9876543210',
        ),
      ),
    );

    expect(display.displayName, 'Fresh User');
    expect(display.displayEmail, 'profile@example.com');
    expect(display.avatarUrl, 'https://example.com/avatar.jpg');
    expect(display.phone, '9876543210');
    expect(display.isSignedIn, isTrue);
  });

  test('profile display falls back to auth email local part', () {
    final display = profileDisplayFor(
      const AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(id: 'user-1', email: 'driver@example.com'),
        profile: UserProfile(id: 'user-1'),
      ),
    );

    expect(display.displayName, 'driver');
    expect(display.displayEmail, 'driver@example.com');
  });

  test('profile display ignores provider seeded Google avatars', () {
    final display = profileDisplayFor(
      const AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(id: 'user-1', email: 'raja@example.com'),
        profile: UserProfile(
          id: 'user-1',
          fullName: 'Raja Raman',
          avatarUrl: 'https://lh3.googleusercontent.com/a/provider-photo',
        ),
      ),
    );

    expect(display.avatarUrl, isNull);
    expect(profileInitials(display.displayName), 'RA');
  });

  test('profile display keeps explicit uploaded avatars', () {
    final display = profileDisplayFor(
      const AuthState(
        status: AuthStatus.authenticated,
        user: AppUser(id: 'user-1', email: 'fresh@example.com'),
        profile: UserProfile(
          id: 'user-1',
          avatarPublicId: 'profiles/user-1/avatar',
          avatarUrl: 'https://res.cloudinary.com/demo/profile.jpg',
          fullName: 'Fresh User',
        ),
      ),
    );

    expect(display.avatarUrl, 'https://res.cloudinary.com/demo/profile.jpg');
  });

  test('realtime profile record maps to user profile', () {
    final profile = userProfileFromRealtimeRecord({
      'id': 'user-1',
      'full_name': 'Live Updated User',
      'email': 'live@example.com',
      'avatar_url': 'https://example.com/live.jpg',
      'avatar_public_id': 'profiles/user-1/avatar',
      'phone': '9123456789',
      'version': 4,
    });

    expect(profile, isNotNull);
    expect(profile!.id, 'user-1');
    expect(profile.fullName, 'Live Updated User');
    expect(profile.email, 'live@example.com');
    expect(profile.avatarUrl, 'https://example.com/live.jpg');
    expect(profile.avatarPublicId, 'profiles/user-1/avatar');
    expect(profile.phone, '9123456789');
    expect(profile.version, 4);
  });

  test('realtime profile record without id is ignored', () {
    expect(userProfileFromRealtimeRecord({'full_name': 'No Id'}), isNull);
  });
}
