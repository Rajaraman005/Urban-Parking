import '../../../shared/validation/indian_vehicle_registration.dart';
import '../../auth/domain/auth_state.dart';

class ProfileVehicle {
  const ProfileVehicle({
    required this.id,
    required this.registration,
    required this.type,
    required this.userId,
    this.createdAt,
    this.isPrimary = false,
    this.make,
    this.model,
    this.updatedAt,
  });

  final DateTime? createdAt;
  final String id;
  final bool isPrimary;
  final String? make;
  final String? model;
  final String registration;
  final String type;
  final DateTime? updatedAt;
  final String userId;

  String get displayRegistration =>
      IndianVehicleRegistration.formatForDisplay(registration);

  static ProfileVehicle fromJson(Map<String, Object?> json) {
    return ProfileVehicle(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: json['vehicle_type']?.toString() ?? '',
      registration: json['vehicle_registration']?.toString() ?? '',
      make: _blankToNull(json['vehicle_make']?.toString()),
      model: _blankToNull(json['vehicle_model']?.toString()),
      isPrimary: _boolFromJson(json['is_primary']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  static ProfileVehicle? fromProfile(UserProfile? profile) {
    if (profile == null) return null;
    final normalizedRegistration = IndianVehicleRegistration.normalize(
      profile.vehicleRegistration ?? '',
    );
    final type = profile.vehicleType?.trim().toLowerCase();
    if (normalizedRegistration == null ||
        normalizedRegistration.isEmpty ||
        (type != 'bike' && type != 'car')) {
      return null;
    }

    return ProfileVehicle(
      id: 'legacy-${profile.id}-$normalizedRegistration',
      userId: profile.id,
      type: type!,
      registration: normalizedRegistration,
      make: _blankToNull(profile.vehicleMake),
      model: _blankToNull(profile.vehicleModel),
      isPrimary: true,
    );
  }
}

List<ProfileVehicle> profileVehiclesFromProfile(UserProfile? profile) {
  final vehicle = ProfileVehicle.fromProfile(profile);
  return vehicle == null ? const [] : [vehicle];
}

String? _blankToNull(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

bool _boolFromJson(Object? value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}
