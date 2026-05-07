enum AuthStatus { idle, hydrating, unauthenticated, authenticated, expired }

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
    this.phone,
    this.gender,
    this.dob,
    this.intent,
    this.setupStep = 'intent',
    this.setupDraftId,
    this.hostParkingDraftId,
    this.onboardingCompletedAt,
    this.version = 1,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final String? phone;
  final String? gender;
  final DateTime? dob;
  final String? intent;
  final String setupStep;
  final String? setupDraftId;
  final String? hostParkingDraftId;
  final DateTime? onboardingCompletedAt;
  final int version;

  bool get hasCompletedOnboarding => onboardingCompletedAt != null;

  static UserProfile fromJson(Map<String, Object?> json) => UserProfile(
    id: json['id'].toString(),
    fullName: json['full_name']?.toString(),
    email: json['email']?.toString(),
    avatarUrl: json['avatar_url']?.toString(),
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
    version: (json['version'] as num?)?.toInt() ?? 1,
  );

  UserProfile copyWith({
    String? avatarUrl,
    DateTime? dob,
    String? email,
    String? fullName,
    String? gender,
    String? intent,
    DateTime? onboardingCompletedAt,
    String? phone,
    String? hostParkingDraftId,
    String? setupDraftId,
    String? setupStep,
    int? version,
  }) {
    return UserProfile(
      id: id,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      dob: dob ?? this.dob,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      gender: gender ?? this.gender,
      intent: intent ?? this.intent,
      hostParkingDraftId: hostParkingDraftId ?? this.hostParkingDraftId,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      phone: phone ?? this.phone,
      setupDraftId: setupDraftId ?? this.setupDraftId,
      setupStep: setupStep ?? this.setupStep,
      version: version ?? this.version,
    );
  }
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
