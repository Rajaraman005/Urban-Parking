import 'package:flutter/material.dart';

import '../../domain/parking_availability.dart';
import 'availability_date_range_field.dart';
import 'availability_time_field.dart';

class ListingAvailabilityValue {
  const ListingAvailabilityValue({
    required this.dailyEndMinute,
    required this.dailyStartMinute,
    required this.skipWeekends,
    this.fromDate,
    this.toDate,
  });

  final int dailyEndMinute;
  final int dailyStartMinute;
  final DateTime? fromDate;
  final bool skipWeekends;
  final DateTime? toDate;

  ListingAvailabilityValue copyWith({
    int? dailyEndMinute,
    int? dailyStartMinute,
    DateTime? fromDate,
    bool? skipWeekends,
    DateTime? toDate,
  }) {
    return ListingAvailabilityValue(
      dailyEndMinute: dailyEndMinute ?? this.dailyEndMinute,
      dailyStartMinute: dailyStartMinute ?? this.dailyStartMinute,
      fromDate: fromDate ?? this.fromDate,
      skipWeekends: skipWeekends ?? this.skipWeekends,
      toDate: toDate ?? this.toDate,
    );
  }
}

class ListingAvailabilityEditor extends StatelessWidget {
  const ListingAvailabilityEditor({
    required this.onChanged,
    required this.value,
    this.enabled = true,
    super.key,
  });

  final bool enabled;
  final ValueChanged<ListingAvailabilityValue> onChanged;
  final ListingAvailabilityValue value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AvailabilityDateRangeField(
          enabled: enabled,
          fromDate: value.fromDate,
          onRangeChanged: (range) {
            onChanged(
              _normalizeForWeekendExclusion(
                value.copyWith(
                  fromDate: parkingDateOnly(range.start),
                  toDate: parkingDateOnly(range.end),
                ),
              ),
            );
          },
          onSkipWeekendsChanged: (skipWeekends) {
            onChanged(
              _normalizeForWeekendExclusion(
                value.copyWith(skipWeekends: skipWeekends),
              ),
            );
          },
          skipWeekends: value.skipWeekends,
          toDate: value.toDate,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AvailabilityTimeField(
                label: 'Daily start',
                value: value.dailyStartMinute,
                onTap: enabled
                    ? () => _pickMinute(context, isStart: true)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AvailabilityTimeField(
                label: 'Daily end',
                value: value.dailyEndMinute,
                onTap: enabled
                    ? () => _pickMinute(context, isStart: false)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickMinute(
    BuildContext context, {
    required bool isStart,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final minMinute = isStart ? 0 : value.dailyStartMinute + 30;
    final maxMinute = isStart ? 1410 : 1440;
    final current = isStart
        ? value.dailyStartMinute
        : normalizeParkingEndMinute(
            value.dailyEndMinute,
            startMinute: value.dailyStartMinute,
          );
    final picked = await showAvailabilityMinutePicker(
      context: context,
      currentValue: current,
      label: isStart ? 'Daily start' : 'Daily end',
      maxMinute: maxMinute,
      minMinute: minMinute,
    );
    if (context.mounted) {
      FocusScope.of(context).unfocus();
    }
    if (picked == null) return;

    if (isStart) {
      final startMinute = normalizeParkingStartMinute(picked);
      final endMinute = value.dailyEndMinute <= startMinute
          ? (startMinute + 30).clamp(30, 1440).toInt()
          : value.dailyEndMinute;
      onChanged(
        value.copyWith(
          dailyEndMinute: endMinute,
          dailyStartMinute: startMinute,
        ),
      );
      return;
    }

    onChanged(
      value.copyWith(
        dailyEndMinute: normalizeParkingEndMinute(
          picked,
          startMinute: value.dailyStartMinute,
        ),
      ),
    );
  }

  ListingAvailabilityValue _normalizeForWeekendExclusion(
    ListingAvailabilityValue next,
  ) {
    if (!next.skipWeekends) return next;

    final fromDate = next.fromDate == null
        ? null
        : nextParkingWeekdayOnOrAfter(next.fromDate!);
    var toDate = next.toDate == null
        ? null
        : previousParkingWeekdayOnOrBefore(next.toDate!);
    if (fromDate != null && toDate != null && toDate.isBefore(fromDate)) {
      toDate = fromDate;
    }

    return next.copyWith(fromDate: fromDate, toDate: toDate);
  }
}
