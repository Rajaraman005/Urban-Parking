DateTime parkingDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int parkingMinuteOfDay(DateTime value) => value.hour * 60 + value.minute;

int normalizeParkingStartMinute(int minute) {
  final rounded = (minute ~/ 30) * 30;
  return rounded.clamp(0, 1410).toInt();
}

int normalizeParkingEndMinute(int minute, {required int startMinute}) {
  final rounded = ((minute + 29) ~/ 30) * 30;
  final clamped = rounded.clamp(30, 1440).toInt();
  if (clamped > startMinute) return clamped;
  return (startMinute + 30).clamp(30, 1440).toInt();
}

String parkingMinuteLabel(int minute) {
  if (minute >= 24 * 60) return '12:00 AM';
  final hour = minute ~/ 60;
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  final displayMinute = (minute % 60).toString().padLeft(2, '0');
  final period = hour < 12 ? 'AM' : 'PM';
  return '$displayHour:$displayMinute $period';
}

bool isParkingWeekend(DateTime value) {
  final weekday = parkingDateOnly(value).weekday;
  return weekday == DateTime.saturday || weekday == DateTime.sunday;
}

DateTime nextParkingWeekdayOnOrAfter(DateTime value) {
  var date = parkingDateOnly(value);
  while (isParkingWeekend(date)) {
    date = date.add(const Duration(days: 1));
  }
  return date;
}

DateTime previousParkingWeekdayOnOrBefore(DateTime value) {
  var date = parkingDateOnly(value);
  while (isParkingWeekend(date)) {
    date = date.subtract(const Duration(days: 1));
  }
  return date;
}

bool parkingRangeContainsBookableDay(
  DateTime from,
  DateTime to, {
  required bool skipWeekends,
}) {
  final start = parkingDateOnly(from);
  final end = parkingDateOnly(to);
  if (end.isBefore(start)) return false;
  if (!skipWeekends) return true;

  var cursor = start;
  while (!cursor.isAfter(end)) {
    if (!isParkingWeekend(cursor)) return true;
    cursor = cursor.add(const Duration(days: 1));
  }
  return false;
}

bool parkingRangeContainsWeekend(DateTime from, DateTime to) {
  var cursor = parkingDateOnly(from);
  final end = parkingDateOnly(to);
  if (end.isBefore(cursor)) return false;

  while (!cursor.isAfter(end)) {
    if (isParkingWeekend(cursor)) return true;
    cursor = cursor.add(const Duration(days: 1));
  }
  return false;
}
