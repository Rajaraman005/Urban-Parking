import 'user_setup_state.dart';

abstract interface class UserSetupRepository {
  Future<UserSetupState> loadSnapshot();
  Future<UserSetupState> saveIntent(String intent);
  Future<UserSetupState> saveProfile({
    required String fullName,
    required String phone,
    required String gender,
    required String dob,
  });
  Future<UserSetupState> saveHostBasics();
  Future<UserSetupState> saveHostPricing();
  Future<UserSetupState> markPhotosStepComplete();
  Future<UserSetupState> submitForReview();
}
