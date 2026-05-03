import 'package:intl/intl.dart';

import '../features/parking/domain/parking_spot.dart';

String formatMoney(num amount, [String currency = 'INR']) {
  final format = NumberFormat.currency(
    locale: 'en_IN',
    symbol: currency == 'INR' ? '₹' : '$currency ',
    decimalDigits: 0,
  );
  return format.format(amount);
}

String formatHourlyMoney(num amount, [String currency = 'INR']) {
  return '${formatMoney(amount, currency)}/hr';
}

String cadenceLabel(BookingCadence cadence) {
  switch (cadence) {
    case BookingCadence.hourly:
      return 'hour';
    case BookingCadence.daily:
      return 'day';
    case BookingCadence.monthly:
      return 'month';
  }
}
