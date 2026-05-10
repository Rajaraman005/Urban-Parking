import '../../parking/domain/owner_parking_repository.dart';
import 'user_setup_state.dart';

abstract interface class UserSetupRepository {
  Future<UserSetupState> loadSnapshot();
  Future<HostListingDraft?> loadHostDraftResumeCandidate();
  Future<UserSetupState> saveIntent(String intent);
  Future<UserSetupState> startHostListing({
    bool createNew = false,
    String? resumeDraftId,
    String? resumeStep,
  });
  Future<UserSetupState> saveProfile({
    required String fullName,
    required String phone,
    required String gender,
    required String dob,
  });
  Future<UserSetupState> saveVehicleDetails({
    bool createNew = false,
    String? previousVehicleRegistration,
    String? vehicleId,
    String? vehicleMake,
    String? vehicleModel,
    required String vehicleRegistration,
    required String vehicleType,
  });
  Future<List<ParkingAddressCandidate>> searchAddress(String query);
  Future<UserSetupState> saveHostBasics(HostBasicsDraftUpdate update);
  Future<UserSetupState> saveHostPricing(HostPricingDraftUpdate update);
  Future<UserSetupState> uploadHostPhoto(HostPhotoUploadCandidate image);
  Future<UserSetupState> deleteHostPhoto(String photoId);
  Future<UserSetupState> reorderHostPhotos(List<String> photoIds);
  Future<UserSetupState> markPhotosStepComplete();
  Future<UserSetupState> submitForReview();
}
