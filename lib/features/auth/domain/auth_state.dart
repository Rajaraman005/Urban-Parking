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
    this.intent,
    this.setupStep = 'intent',
    this.setupDraftId,
    this.onboardingCompletedAt,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final String? intent;
  final String setupStep;
  final String? setupDraftId;
  final DateTime? onboardingCompletedAt;

  bool get hasCompletedOnboarding => onboardingCompletedAt != null;

  static UserProfile fromJson(Map<String, Object?> json) => UserProfile(
    id: json['id'].toString(),
    fullName: json['full_name']?.toString(),
    email: json['email']?.toString(),
    avatarUrl: json['avatar_url']?.toString(),
    intent: json['intent']?.toString(),
    setupStep: json['setup_step']?.toString() ?? 'intent',
    setupDraftId: json['setup_draft_id']?.toString(),
    onboardingCompletedAt: DateTime.tryParse(
      json['onboarding_completed_at']?.toString() ?? '',
    ),
  );
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
