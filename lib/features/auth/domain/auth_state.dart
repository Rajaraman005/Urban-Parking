enum AuthStatus { idle, hydrating, unauthenticated, authenticated, expired }

enum BookingApprovalMode {
  manual,
  auto;

  static BookingApprovalMode fromJson(Object? value) {
    return switch (value?.toString().trim()) {
      'auto' => BookingApprovalMode.auto,
      _ => BookingApprovalMode.manual,
    };
  }
}

class AppUser {
  const AppUser({required this.id, this.email});

  final String id;
  final String? email;
}

class UserProfile {
  const UserProfile({
    required this.id,
    this.fullName,
    this.email,
    this.avatarUrl,
    this.avatarPublicId,
    this.phone,
    this.gender,
    this.dob,
    this.intent,
    this.setupStep = 'intent',
    this.setupDraftId,
    this.hostParkingDraftId,
    this.onboardingCompletedAt,
    this.bookingApprovalMode = BookingApprovalMode.manual,
    this.showPhoneNumber = false,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleRegistration,
    this.vehicleType,
    this.version = 1,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final String? avatarPublicId;
  final String? phone;
  final String? gender;
  final DateTime? dob;
  final String? intent;
  final String setupStep;
  final String? setupDraftId;
  final String? hostParkingDraftId;
  final DateTime? onboardingCompletedAt;
  final BookingApprovalMode bookingApprovalMode;
  final bool showPhoneNumber;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleRegistration;
  final String? vehicleType;
  final int version;

  bool get hasCompletedOnboarding => onboardingCompletedAt != null;

  static UserProfile fromJson(Map<String, Object?> json) => UserProfile(
    id: json['id'].toString(),
    fullName: json['full_name']?.toString(),
    email: json['email']?.toString(),
    avatarUrl: json['avatar_url']?.toString(),
    avatarPublicId: json['avatar_public_id']?.toString(),
    phone: json['phone']?.toString(),
    gender: json['gender']?.toString(),
    dob: DateTime.tryParse(json['dob']?.toString() ?? ''),
    intent: json['intent']?.toString(),
    setupStep: json['setup_step']?.toString() ?? 'intent',
    setupDraftId: json['setup_draft_id']?.toString(),
    hostParkingDraftId: json['host_parking_draft_id']?.toString(),
    onboardingCompletedAt: DateTime.tryParse(
      json['onboarding_completed_at']?.toString() ?? '',
    ),
    bookingApprovalMode: BookingApprovalMode.fromJson(
      json['booking_approval_mode'] ?? json['bookingApprovalMode'],
    ),
    showPhoneNumber: _boolFromJson(
      json['show_phone_number'] ?? json['showPhoneNumber'],
    ),
    vehicleMake: json['vehicle_make']?.toString(),
    vehicleModel: json['vehicle_model']?.toString(),
    vehicleRegistration: json['vehicle_registration']?.toString(),
    vehicleType: json['vehicle_type']?.toString(),
    version: _intFromJson(json['version'], fallback: 1),
  );

  UserProfile copyWith({
    String? avatarUrl,
    String? avatarPublicId,
    bool clearAvatarUrl = false,
    bool clearAvatarPublicId = false,
    DateTime? dob,
    bool clearDob = false,
    String? email,
    String? fullName,
    String? gender,
    bool clearGender = false,
    String? intent,
    bool clearIntent = false,
    DateTime? onboardingCompletedAt,
    String? phone,
    bool clearPhone = false,
    String? hostParkingDraftId,
    bool clearHostParkingDraftId = false,
    String? setupDraftId,
    bool clearSetupDraftId = false,
    String? setupStep,
    BookingApprovalMode? bookingApprovalMode,
    bool? showPhoneNumber,
    String? vehicleMake,
    bool clearVehicleMake = false,
    String? vehicleModel,
    bool clearVehicleModel = false,
    String? vehicleRegistration,
    bool clearVehicleRegistration = false,
    String? vehicleType,
    bool clearVehicleType = false,
    int? version,
  }) {
    return UserProfile(
      id: id,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      avatarPublicId: clearAvatarPublicId
          ? null
          : avatarPublicId ?? this.avatarPublicId,
      dob: clearDob ? null : dob ?? this.dob,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      gender: clearGender ? null : gender ?? this.gender,
      intent: clearIntent ? null : intent ?? this.intent,
      hostParkingDraftId: clearHostParkingDraftId
          ? null
          : hostParkingDraftId ?? this.hostParkingDraftId,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      bookingApprovalMode: bookingApprovalMode ?? this.bookingApprovalMode,
      showPhoneNumber: showPhoneNumber ?? this.showPhoneNumber,
      phone: clearPhone ? null : phone ?? this.phone,
      setupDraftId: clearSetupDraftId
          ? null
          : setupDraftId ?? this.setupDraftId,
      setupStep: setupStep ?? this.setupStep,
      vehicleMake: clearVehicleMake ? null : vehicleMake ?? this.vehicleMake,
      vehicleModel: clearVehicleModel
          ? null
          : vehicleModel ?? this.vehicleModel,
      vehicleRegistration: clearVehicleRegistration
          ? null
          : vehicleRegistration ?? this.vehicleRegistration,
      vehicleType: clearVehicleType ? null : vehicleType ?? this.vehicleType,
      version: version ?? this.version,
    );
  }
}

bool _boolFromJson(Object? value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

int _intFromJson(Object? value, {required int fallback}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.profile,
    this.errorMessage,
  });

  const AuthState.idle() : this(status: AuthStatus.idle);

  final AuthStatus status;
  final AppUser? user;
  final UserProfile? profile;
  final String? errorMessage;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    UserProfile? profile,
    String? errorMessage,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    profile: profile ?? this.profile,
    errorMessage: errorMessage,
  );
}
