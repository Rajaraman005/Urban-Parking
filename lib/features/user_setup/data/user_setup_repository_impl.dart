import '../../../core/utils/telemetry.dart';
import '../domain/user_setup_repository.dart';
import '../domain/user_setup_state.dart';

class UserSetupRepositoryImpl implements UserSetupRepository {
  UserSetupState _state = const UserSetupState();

  @override
  Future<UserSetupState> loadSnapshot() async => _state;

  @override
  Future<UserSetupState> saveIntent(String intent) async {
    _state = _state.copyWith(
      intent: intent,
      step: 'profile',
      message: 'Intent saved',
    );
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'intent'});
    return _state;
  }

  @override
  Future<UserSetupState> saveProfile({
    required String fullName,
    required String phone,
    required String gender,
    required String dob,
  }) async {
    final next = _state.intent == 'host' ? 'host_basics' : 'complete';
    _state = _state.copyWith(step: next, message: 'Profile saved');
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'profile'});
    return _state;
  }

  @override
  Future<UserSetupState> saveHostBasics() async {
    _state = _state.copyWith(step: 'host_pricing', draftId: 'local-draft');
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_basics'});
    return _state;
  }

  @override
  Future<UserSetupState> saveHostPricing() async {
    _state = _state.copyWith(step: 'host_photos');
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_pricing'});
    return _state;
  }

  @override
  Future<UserSetupState> markPhotosStepComplete() async {
    _state = _state.copyWith(step: 'host_review');
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_photos'});
    return _state;
  }

  @override
  Future<UserSetupState> submitForReview() async {
    _state = _state.copyWith(step: 'complete');
    telemetry.event(TelemetryEvent.setupStepSaved, {'step': 'host_review'});
    return _state;
  }
}
