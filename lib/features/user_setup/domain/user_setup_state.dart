class UserSetupState {
  const UserSetupState({
    this.intent,
    this.step = 'intent',
    this.draftId,
    this.message,
  });

  final String? intent;
  final String step;
  final String? draftId;
  final String? message;

  UserSetupState copyWith({
    String? intent,
    String? step,
    String? draftId,
    String? message,
  }) => UserSetupState(
    intent: intent ?? this.intent,
    step: step ?? this.step,
    draftId: draftId ?? this.draftId,
    message: message,
  );
}
