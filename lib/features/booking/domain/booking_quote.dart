class BookingQuote {
  const BookingQuote({
    required this.spotId,
    required this.startAt,
    required this.endAt,
    required this.subtotal,
    required this.platformFee,
    required this.taxes,
    required this.total,
    required this.currency,
  });

  final String spotId;
  final DateTime startAt;
  final DateTime endAt;
  final int subtotal;
  final int platformFee;
  final int taxes;
  final int total;
  final String currency;

  BookingQuote copyWith({
    String? spotId,
    DateTime? startAt,
    DateTime? endAt,
    int? subtotal,
    int? platformFee,
    int? taxes,
    int? total,
    String? currency,
  }) {
    return BookingQuote(
      spotId: spotId ?? this.spotId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      subtotal: subtotal ?? this.subtotal,
      platformFee: platformFee ?? this.platformFee,
      taxes: taxes ?? this.taxes,
      total: total ?? this.total,
      currency: currency ?? this.currency,
    );
  }

  static BookingQuote fromJson(Map<String, Object?> json) => BookingQuote(
    spotId: json['spotId'].toString(),
    startAt: DateTime.parse(json['startAt'].toString()),
    endAt: DateTime.parse(json['endAt'].toString()),
    subtotal: (json['subtotal'] as num).toInt(),
    platformFee: (json['platformFee'] as num).toInt(),
    taxes: (json['taxes'] as num).toInt(),
    total: (json['total'] as num).toInt(),
    currency: json['currency']?.toString() ?? 'INR',
  );
}
