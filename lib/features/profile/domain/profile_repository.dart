import 'dart:typed_data';

import '../../auth/domain/auth_state.dart';

class ProfileBookingControlsUpdate {
  const ProfileBookingControlsUpdate({
    required this.bookingApprovalMode,
    required this.expectedVersion,
    required this.showPhoneNumber,
  });

  final BookingApprovalMode bookingApprovalMode;
  final int expectedVersion;
  final bool showPhoneNumber;
}

class ProfileDetailsUpdate {
  const ProfileDetailsUpdate({
    required this.expectedVersion,
    required this.fullName,
    this.dob,
    this.gender,
    this.phone,
  });

  final DateTime? dob;
  final int expectedVersion;
  final String fullName;
  final String? gender;
  final String? phone;
}

class ProfileAvatarUploadCandidate {
  const ProfileAvatarUploadCandidate({
    required this.bytes,
    required this.fileName,
    required this.height,
    required this.mimeType,
    required this.width,
  });

  final Uint8List bytes;
  final String fileName;
  final int height;
  final String mimeType;
  final int width;
}

abstract interface class ProfileRepository {
  Future<UserProfile> reload();
  Future<UserProfile> updateAvatar(ProfileAvatarUploadCandidate image);
  Future<UserProfile> updateBookingControls(
    ProfileBookingControlsUpdate update,
  );
  Future<UserProfile> updatePersonalDetails(ProfileDetailsUpdate update);
}
