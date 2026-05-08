import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../shared/validation/indian_mobile_number.dart';
import '../../auth/domain/auth_state.dart';
import '../domain/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({Dio? dio}) : _dio = dio ?? Dio();

  static const _maxAvatarBytes = 5 * 1024 * 1024;
  static const _minAvatarDimension = 256;
  static const _uuid = Uuid();

  final Dio _dio;

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<UserProfile> reload() async {
    _assertConfigured();
    final data = await _client.rpc('ensure_user_profile');
    if (data is Map) {
      return UserProfile.fromJson(Map<String, Object?>.from(data));
    }
    throw const AuthFailure(
      'Could not load your profile.',
      code: 'profile_load_failed',
    );
  }

  @override
  Future<UserProfile> updatePersonalDetails(ProfileDetailsUpdate update) async {
    _assertConfigured();
    _assertAuthenticated();

    final fullName = update.fullName.trim();
    if (fullName.length < 2) {
      throw const ValidationFailure(
        'Enter your full name.',
        code: 'profile_full_name_required',
      );
    }

    final phone = _normalizePhone(update.phone);
    final gender = _normalizeGender(update.gender);
    final dob = update.dob;
    if (dob != null && _isFutureDate(dob)) {
      throw const ValidationFailure(
        'Date of birth cannot be in the future.',
        code: 'profile_dob_future',
      );
    }

    final payload = <String, Object?>{
      'full_name': fullName,
      'phone': phone,
      'gender': gender,
      'dob': dob == null ? null : _dateOnly(dob),
      'version': update.expectedVersion + 1,
    };

    try {
      final row = await _client
          .from('profiles')
          .update(payload)
          .eq('id', _client.auth.currentUser!.id)
          .eq('version', update.expectedVersion)
          .select()
          .maybeSingle();

      if (row == null) {
        throw const ValidationFailure(
          'Your profile changed elsewhere. Refresh and try again.',
          code: 'profile_version_conflict',
        );
      }

      return UserProfile.fromJson(Map<String, Object?>.from(row));
    } on AppFailure {
      rethrow;
    } on sb.PostgrestException catch (error) {
      throw AuthFailure(
        'Could not update your profile. Please try again.',
        code: error.code ?? 'profile_update_failed',
      );
    }
  }

  @override
  Future<UserProfile> updateBookingControls(
    ProfileBookingControlsUpdate update,
  ) async {
    _assertConfigured();
    _assertAuthenticated();

    try {
      final response = await _client.rpc(
        'update_profile_booking_controls',
        params: {
          'p_booking_approval_mode': update.bookingApprovalMode.name,
          'p_expected_version': update.expectedVersion,
          'p_show_phone_number': update.showPhoneNumber,
        },
      );

      if (response is Map) {
        return UserProfile.fromJson(Map<String, Object?>.from(response));
      }

      throw const AuthFailure(
        'Profile controls returned an invalid response.',
        code: 'profile_controls_invalid_response',
      );
    } on AppFailure {
      rethrow;
    } on sb.PostgrestException catch (error) {
      final code = error.code ?? 'profile_controls_update_failed';
      if (code == '40001') {
        throw const ValidationFailure(
          'Your profile changed elsewhere. Refresh and try again.',
          code: 'profile_version_conflict',
        );
      }
      if (code == '23514') {
        throw const ValidationFailure(
          'Choose valid privacy controls.',
          code: 'profile_controls_invalid',
        );
      }
      throw AuthFailure(
        'Could not update privacy controls. Please try again.',
        code: code,
      );
    }
  }

  @override
  Future<UserProfile> updateAvatar(ProfileAvatarUploadCandidate image) async {
    _assertConfigured();
    _assertAuthenticated();
    _validateAvatar(image);

    final uploadId = _uuid.v4();
    final sequence = DateTime.now().microsecondsSinceEpoch;

    try {
      final signature =
          await _invokeFunctionData('create-profile-avatar-upload-signature', {
            'fileName': image.fileName,
            'fileSize': image.bytes.length,
            'height': image.height,
            'mimeType': image.mimeType,
            'sequence': sequence,
            'uploadId': uploadId,
            'width': image.width,
          });

      final cloudName = _requiredString(signature, 'cloudName');
      final uploadResponse = await _dio.post<Map<String, Object?>>(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
        data: FormData.fromMap({
          'api_key': _requiredString(signature, 'apiKey'),
          'file': MultipartFile.fromBytes(
            image.bytes,
            filename: image.fileName,
            contentType: DioMediaType.parse(image.mimeType),
          ),
          'public_id': _requiredString(signature, 'publicId'),
          'signature': _requiredString(signature, 'signature'),
          'timestamp': signature['timestamp'],
        }),
      );

      final upload = uploadResponse.data;
      if (upload == null) {
        throw const NetworkFailure(
          'Cloudinary did not return upload details.',
          code: 'cloudinary_empty_response',
        );
      }

      final complete =
          await _invokeFunctionData('complete-profile-avatar-upload', {
            'bytes': upload['bytes'],
            'format': upload['format'],
            'height': upload['height'],
            'publicId': upload['public_id'],
            'secureUrl': upload['secure_url'],
            'sequence': sequence,
            'uploadId': uploadId,
            'width': upload['width'],
          });

      final profile = complete['profile'];
      if (profile is! Map) {
        throw const AuthFailure(
          'Could not activate the uploaded profile photo.',
          code: 'profile_avatar_activation_failed',
        );
      }

      return UserProfile.fromJson(Map<String, Object?>.from(profile));
    } on AppFailure {
      rethrow;
    } on DioException catch (error) {
      throw NetworkFailure(
        'Profile photo upload failed. Please try again.',
        code: error.response?.statusCode?.toString() ?? 'avatar_upload_failed',
      );
    } on sb.FunctionException catch (error) {
      throw AuthFailure(
        'Profile photo upload is temporarily unavailable.',
        code: 'profile_avatar_function_${error.status}',
      );
    }
  }

  Future<Map<String, Object?>> _invokeFunctionData(
    String name,
    Map<String, Object?> body,
  ) async {
    final response = await _client.functions.invoke(name, body: body);
    final data = response.data;
    if (response.status >= 400 || data is! Map || data['ok'] != true) {
      throw AuthFailure(
        data is Map
            ? data['message']?.toString() ?? 'Profile service failed.'
            : 'Profile service failed.',
        code: data is Map ? data['code']?.toString() : name,
      );
    }

    final payload = data['data'];
    if (payload is! Map) {
      throw AuthFailure(
        'Profile service returned an invalid response.',
        code: '${name}_invalid_response',
      );
    }
    return Map<String, Object?>.from(payload);
  }

  String _requiredString(Map<String, Object?> data, String key) {
    final value = data[key]?.toString();
    if (value == null || value.isEmpty) {
      throw AuthFailure(
        'Profile service returned an invalid response.',
        code: 'missing_$key',
      );
    }
    return value;
  }

  void _validateAvatar(ProfileAvatarUploadCandidate image) {
    if (image.bytes.isEmpty || image.bytes.length > _maxAvatarBytes) {
      throw const ValidationFailure(
        'Profile photo must be 5MB or smaller.',
        code: 'profile_avatar_size',
      );
    }
    if (image.width < _minAvatarDimension ||
        image.height < _minAvatarDimension) {
      throw const ValidationFailure(
        'Profile photo must be at least 256px wide and tall.',
        code: 'profile_avatar_dimensions',
      );
    }
    if (!const {
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
    }.contains(image.mimeType.toLowerCase())) {
      throw const ValidationFailure(
        'Upload a JPG, PNG, or WebP profile photo.',
        code: 'profile_avatar_type',
      );
    }
  }

  String? _normalizePhone(String? rawPhone) {
    final value = rawPhone?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }

    final issue = IndianMobileNumber.issue(value);
    if (issue != null) {
      throw ValidationFailure(
        IndianMobileNumber.message(issue),
        code: 'profile_phone_invalid',
      );
    }

    return IndianMobileNumber.normalize(value);
  }

  String? _normalizeGender(String? rawGender) {
    final value = rawGender?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    if (!const {
      'male',
      'female',
      'other',
      'prefer_not_to_say',
    }.contains(value)) {
      throw const ValidationFailure(
        'Choose a valid gender option.',
        code: 'profile_gender_invalid',
      );
    }
    return value;
  }

  bool _isFutureDate(DateTime value) {
    final today = DateTime.now();
    final date = DateTime(value.year, value.month, value.day);
    return date.isAfter(DateTime(today.year, today.month, today.day));
  }

  String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  void _assertConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const ConfigurationFailure(
        'Supabase is not configured for this build.',
        code: 'supabase_not_configured',
      );
    }
  }

  void _assertAuthenticated() {
    if (_client.auth.currentUser == null) {
      throw const AuthFailure('Session expired.', code: 'session_expired');
    }
  }
}
