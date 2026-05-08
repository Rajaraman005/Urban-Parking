enum BookingStatus {
  pending,
  approved,
  rejected,
  expired;

  bool get isTerminal => switch (this) {
    BookingStatus.rejected || BookingStatus.expired => true,
    BookingStatus.pending || BookingStatus.approved => false,
  };

  static BookingStatus fromJson(Object? value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'approved' => BookingStatus.approved,
      'rejected' => BookingStatus.rejected,
      'expired' => BookingStatus.expired,
      _ => BookingStatus.pending,
    };
  }
}

enum BookingListRole { host, renter }

class ParkingBooking {
  const ParkingBooking({
    required this.currency,
    required this.endAt,
    required this.hostId,
    required this.id,
    required this.idempotencyKey,
    required this.platformFee,
    required this.renterId,
    required this.requestHash,
    required this.slotNumber,
    required this.spotId,
    required this.startAt,
    required this.status,
    required this.subtotal,
    required this.taxes,
    required this.total,
    required this.updatedAt,
    required this.vehicleKind,
    required this.version,
    this.createdAt,
    this.expiresAt,
    this.hostAvatarUrl,
    this.hostName,
    this.renterAvatarUrl,
    this.renterName,
    this.spotAddress,
    this.spotLocality,
    this.spotTitle,
  });

  final DateTime? createdAt;
  final String currency;
  final DateTime endAt;
  final DateTime? expiresAt;
  final String? hostAvatarUrl;
  final String hostId;
  final String? hostName;
  final String id;
  final String idempotencyKey;
  final int platformFee;
  final String? renterAvatarUrl;
  final String renterId;
  final String? renterName;
  final String requestHash;
  final int slotNumber;
  final String? spotAddress;
  final String spotId;
  final String? spotLocality;
  final String? spotTitle;
  final DateTime startAt;
  final BookingStatus status;
  final int subtotal;
  final int taxes;
  final int total;
  final DateTime updatedAt;
  final String vehicleKind;
  final int version;

  String get displayTitle {
    final title = spotTitle?.trim();
    if (title != null && title.isNotEmpty) return title;
    return 'Parking request';
  }

  String get displayLocation {
    final address = spotAddress?.trim();
    if (address != null && address.isNotEmpty) return address;
    final locality = spotLocality?.trim();
    if (locality != null && locality.isNotEmpty) return locality;
    return 'Slot $slotNumber';
  }

  ParkingBooking copyWith({
    BookingStatus? status,
    DateTime? updatedAt,
    int? version,
  }) {
    return ParkingBooking(
      createdAt: createdAt,
      currency: currency,
      endAt: endAt,
      expiresAt: expiresAt,
      hostAvatarUrl: hostAvatarUrl,
      hostId: hostId,
      hostName: hostName,
      id: id,
      idempotencyKey: idempotencyKey,
      platformFee: platformFee,
      renterAvatarUrl: renterAvatarUrl,
      renterId: renterId,
      renterName: renterName,
      requestHash: requestHash,
      slotNumber: slotNumber,
      spotAddress: spotAddress,
      spotId: spotId,
      spotLocality: spotLocality,
      spotTitle: spotTitle,
      startAt: startAt,
      status: status ?? this.status,
      subtotal: subtotal,
      taxes: taxes,
      total: total,
      updatedAt: updatedAt ?? this.updatedAt,
      vehicleKind: vehicleKind,
      version: version ?? this.version,
    );
  }

  static ParkingBooking fromJson(Object? json) {
    final map = Map<String, Object?>.from(json as Map);
    return ParkingBooking(
      createdAt: _dateTimeFrom(map, const ['createdAt', 'created_at']),
      currency: _stringFrom(map, const ['currency']) ?? 'INR',
      endAt: _requiredDateTimeFrom(map, const ['endAt', 'end_at']),
      expiresAt: _dateTimeFrom(map, const ['expiresAt', 'expires_at']),
      hostAvatarUrl: _stringFrom(map, const [
        'hostAvatarUrl',
        'host_avatar_url',
      ]),
      hostId: _stringFrom(map, const ['hostId', 'host_id']) ?? '',
      hostName: _stringFrom(map, const ['hostName', 'host_name']),
      id: _stringFrom(map, const ['id']) ?? '',
      idempotencyKey:
          _stringFrom(map, const ['idempotencyKey', 'idempotency_key']) ?? '',
      platformFee: _intFrom(map, const ['platformFee', 'platform_fee']),
      renterAvatarUrl: _stringFrom(map, const [
        'renterAvatarUrl',
        'renter_avatar_url',
      ]),
      renterId: _stringFrom(map, const ['renterId', 'renter_id']) ?? '',
      renterName: _stringFrom(map, const ['renterName', 'renter_name']),
      requestHash:
          _stringFrom(map, const ['requestHash', 'request_hash']) ?? '',
      slotNumber: _intFrom(map, const ['slotNumber', 'slot_number']),
      spotAddress: _stringFrom(map, const ['spotAddress', 'spot_address']),
      spotId: _stringFrom(map, const ['spotId', 'spot_id', 'space_id']) ?? '',
      spotLocality: _stringFrom(map, const ['spotLocality', 'spot_locality']),
      spotTitle: _stringFrom(map, const ['spotTitle', 'spot_title']),
      startAt: _requiredDateTimeFrom(map, const ['startAt', 'start_at']),
      status: BookingStatus.fromJson(map['status']),
      subtotal: _intFrom(map, const ['subtotal']),
      taxes: _intFrom(map, const ['taxes']),
      total: _intFrom(map, const ['total']),
      updatedAt:
          _dateTimeFrom(map, const ['updatedAt', 'updated_at']) ??
          DateTime.now(),
      vehicleKind:
          _stringFrom(map, const ['vehicleKind', 'vehicle_kind']) ?? 'car',
      version: _intFrom(map, const ['version'], fallback: 1),
    );
  }
}

class CreateBookingRequest {
  const CreateBookingRequest({
    required this.endAt,
    required this.idempotencyKey,
    required this.spotId,
    required this.startAt,
    required this.vehicleKind,
  });

  final DateTime endAt;
  final String idempotencyKey;
  final String spotId;
  final DateTime startAt;
  final String vehicleKind;

  Map<String, Object?> toJson() => {
    'endAt': endAt.toIso8601String(),
    'idempotencyKey': idempotencyKey,
    'spotId': spotId,
    'startAt': startAt.toIso8601String(),
    'vehicleKind': vehicleKind,
  };
}

String? _stringFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

int _intFrom(Map<String, Object?> map, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

DateTime _requiredDateTimeFrom(Map<String, Object?> map, List<String> keys) {
  return _dateTimeFrom(map, keys) ?? DateTime.now();
}

DateTime? _dateTimeFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final raw = map[key];
    if (raw == null) continue;
    if (raw is DateTime) return raw;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed != null) return parsed;
  }
  return null;
}
