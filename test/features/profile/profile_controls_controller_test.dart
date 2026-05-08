import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/core/errors/app_failure.dart';
import 'package:urban_parking/features/auth/domain/auth_state.dart';
import 'package:urban_parking/features/auth/presentation/auth_controller.dart';
import 'package:urban_parking/features/profile/domain/profile_repository.dart';
import 'package:urban_parking/features/profile/presentation/profile_controls_controller.dart';
import 'package:urban_parking/features/profile/presentation/profile_details_controller.dart';

void main() {
  test(
    'profile controls update optimistically and roll back on failure',
    () async {
      final repository = _FakeProfileRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => _FakeAuthController()),
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);

      final future = container
          .read(profileControlsControllerProvider.notifier)
          .updateControls(
            bookingApprovalMode: BookingApprovalMode.auto,
            showPhoneNumber: true,
          );

      var profile = container.read(authControllerProvider).value!.profile!;
      expect(profile.showPhoneNumber, isTrue);
      expect(profile.bookingApprovalMode, BookingApprovalMode.auto);
      expect(profile.version, 8);

      repository.completeError(
        const ValidationFailure(
          'Your profile changed elsewhere. Refresh and try again.',
          code: 'profile_version_conflict',
        ),
      );
      await expectLater(future, throwsA(isA<ValidationFailure>()));

      profile = container.read(authControllerProvider).value!.profile!;
      expect(profile.showPhoneNumber, isFalse);
      expect(profile.bookingApprovalMode, BookingApprovalMode.manual);
      expect(profile.version, 7);
    },
  );
}

class _FakeAuthController extends AuthController {
  @override
  Future<AuthState> build() async {
    return const AuthState(
      status: AuthStatus.authenticated,
      user: AppUser(id: 'user-1', email: 'host@example.com'),
      profile: UserProfile(
        id: 'user-1',
        email: 'host@example.com',
        fullName: 'Test Host',
        version: 7,
      ),
    );
  }
}

class _FakeProfileRepository implements ProfileRepository {
  final _updateCompleter = Completer<UserProfile>();

  void completeError(AppFailure failure) {
    _updateCompleter.completeError(failure);
  }

  @override
  Future<UserProfile> reload() async {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> updateAvatar(ProfileAvatarUploadCandidate image) async {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> updateBookingControls(
    ProfileBookingControlsUpdate update,
  ) {
    return _updateCompleter.future;
  }

  @override
  Future<UserProfile> updatePersonalDetails(ProfileDetailsUpdate update) async {
    throw UnimplementedError();
  }
}
