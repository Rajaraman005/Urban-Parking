import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/parking_availability.dart';
import 'availability_field_label.dart';

class AvailabilityDateRangeField extends StatelessWidget {
  const AvailabilityDateRangeField({
    required this.fromDate,
    required this.onRangeChanged,
    required this.onSkipWeekendsChanged,
    required this.skipWeekends,
    required this.toDate,
    this.enabled = true,
    super.key,
  });

  final bool enabled;
  final DateTime? fromDate;
  final ValueChanged<DateTimeRange> onRangeChanged;
  final ValueChanged<bool> onSkipWeekendsChanged;
  final bool skipWeekends;
  final DateTime? toDate;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: enabled ? () => _pickDateRange(context) : null,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range_rounded,
                      color: Color(0xFF0B0B0C),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    AvailabilityFieldLabel('Date range'),
                  ],
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: enabled ? () => _pickDateRange(context) : null,
              child: Row(
                children: [
                  Expanded(
                    child: _RangeEndpointPill(
                      label: 'Start',
                      value: fromDate == null
                          ? 'Choose start'
                          : DateFormat('d MMM yyyy').format(fromDate!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RangeEndpointPill(
                      label: 'End',
                      value: toDate == null
                          ? 'Choose end'
                          : DateFormat('d MMM yyyy').format(toDate!),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ExcludeWeekendsToggle(
              value: skipWeekends,
              onChanged: enabled ? onSkipWeekendsChanged : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final today = parkingDateOnly(now);
    final firstAllowed = [fromDate, toDate, today]
        .whereType<DateTime>()
        .map(parkingDateOnly)
        .reduce((left, right) => left.isBefore(right) ? left : right);
    final initialStart = fromDate == null || fromDate!.isBefore(firstAllowed)
        ? firstAllowed
        : parkingDateOnly(fromDate!);
    final initialEnd = toDate == null || toDate!.isBefore(initialStart)
        ? initialStart
        : parkingDateOnly(toDate!);
    final defaultLastAllowed = DateTime(now.year + 2, now.month, now.day);
    final lastAllowed = initialEnd.isAfter(defaultLastAllowed)
        ? initialEnd
        : defaultLastAllowed;
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (context) => _DateRangePickerDialog(
        excludeWeekends: skipWeekends,
        firstDate: firstAllowed,
        initialEnd: initialEnd,
        initialStart: initialStart,
        lastDate: lastAllowed,
      ),
    );
    if (context.mounted) {
      FocusScope.of(context).unfocus();
    }
    if (picked == null) return;
    onRangeChanged(picked);
  }
}

class _ExcludeWeekendsToggle extends StatelessWidget {
  const _ExcludeWeekendsToggle({required this.onChanged, required this.value});

  final ValueChanged<bool>? onChanged;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Material(
      color: const Color(0xFFF7F7F9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled
            ? () {
                FocusManager.instance.primaryFocus?.unfocus();
                onChanged!(!value);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Except Sat/Sun',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled
                        ? const Color(0xFF0B0B0C)
                        : const Color(0xFFA1A1AA),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              _ToggleSwitch(value: value, enabled: enabled),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  const _ToggleSwitch({required this.enabled, required this.value});

  final bool enabled;
  final bool value;

  @override
  Widget build(BuildContext context) {
    final trackColor = value
        ? const Color(0xFF0B0B0C)
        : const Color(0xFFE4E4E7);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: enabled ? trackColor : const Color(0xFFE4E4E7),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFD4D4D8)),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _RangeEndpointPill extends StatelessWidget {
  const _RangeEndpointPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0B0B0C),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateRangePickerDialog extends StatefulWidget {
  const _DateRangePickerDialog({
    required this.excludeWeekends,
    required this.firstDate,
    required this.initialEnd,
    required this.initialStart,
    required this.lastDate,
  });

  final bool excludeWeekends;
  final DateTime firstDate;
  final DateTime initialEnd;
  final DateTime initialStart;
  final DateTime lastDate;

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  late DateTime _displayMonth;
  late DateTime? _endDate;
  late DateTime? _startDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.excludeWeekends
        ? nextParkingWeekdayOnOrAfter(widget.initialStart)
        : parkingDateOnly(widget.initialStart);
    _endDate = widget.excludeWeekends
        ? previousParkingWeekdayOnOrBefore(widget.initialEnd)
        : parkingDateOnly(widget.initialEnd);
    if (_endDate != null &&
        _startDate != null &&
        _endDate!.isBefore(_startDate!)) {
      _endDate = _startDate;
    }
    _displayMonth = DateTime(
      widget.initialStart.year,
      widget.initialStart.month,
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(_displayMonth);
    final canGoBack =
        _previousMonth(
          _displayMonth,
        ).isAfter(DateTime(widget.firstDate.year, widget.firstDate.month)) ||
        _sameMonth(_previousMonth(_displayMonth), widget.firstDate);
    final canGoForward =
        _nextMonth(
          _displayMonth,
        ).isBefore(DateTime(widget.lastDate.year, widget.lastDate.month)) ||
        _sameMonth(_nextMonth(_displayMonth), widget.lastDate);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = screenHeight - 64;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 390, maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select dates',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF0B0B0C),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _SelectedRangeHeader(startDate: _startDate, endDate: _endDate),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: canGoBack
                          ? () => setState(() {
                              _displayMonth = _previousMonth(_displayMonth);
                            })
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        monthLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0B0B0C),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: canGoForward
                          ? () => setState(() {
                              _displayMonth = _nextMonth(_displayMonth);
                            })
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const _WeekdayHeader(),
                const SizedBox(height: 6),
                _MonthGrid(
                  displayMonth: _displayMonth,
                  endDate: _endDate,
                  excludeWeekends: widget.excludeWeekends,
                  firstDate: widget.firstDate,
                  lastDate: widget.lastDate,
                  onSelect: _selectDate,
                  startDate: _startDate,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: const Color(0xFF0B0B0C),
                          side: const BorderSide(color: Color(0xFF0B0B0C)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _startDate == null
                            ? null
                            : () {
                                final start = _startDate!;
                                final end = _endDate ?? start;
                                Navigator.of(
                                  context,
                                ).pop(DateTimeRange(start: start, end: end));
                              },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: const Color(0xFF0B0B0C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        child: const Text(
                          'Save Date',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectDate(DateTime date) {
    if (widget.excludeWeekends && isParkingWeekend(date)) return;

    setState(() {
      final selected = parkingDateOnly(date);
      if (_startDate == null || _endDate != null) {
        _startDate = selected;
        _endDate = null;
        return;
      }

      if (selected.isBefore(_startDate!)) {
        _startDate = selected;
        _endDate = null;
        return;
      }

      _endDate = selected;
    });
  }
}

class _SelectedRangeHeader extends StatelessWidget {
  const _SelectedRangeHeader({required this.endDate, required this.startDate});

  final DateTime? endDate;
  final DateTime? startDate;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E4E7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF71717A),
              size: 18,
            ),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _RangeSummaryText(
                      label: 'Start',
                      textAlign: TextAlign.left,
                      value: startDate == null
                          ? 'Choose start'
                          : dateFormat.format(startDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 44),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _RangeSummaryText(
                      label: 'End',
                      textAlign: TextAlign.right,
                      value: endDate == null
                          ? 'Choose end'
                          : dateFormat.format(endDate!),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeSummaryText extends StatelessWidget {
  const _RangeSummaryText({
    required this.label,
    required this.textAlign,
    required this.value,
  });

  final String label;
  final TextAlign textAlign;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: Column(
        crossAxisAlignment: textAlign == TextAlign.right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: const TextStyle(
              color: Color(0xFF71717A),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: const TextStyle(
              color: Color(0xFF0B0B0C),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const _labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in _labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF71717A),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.displayMonth,
    required this.endDate,
    required this.excludeWeekends,
    required this.firstDate,
    required this.lastDate,
    required this.onSelect,
    required this.startDate,
  });

  final DateTime displayMonth;
  final DateTime? endDate;
  final bool excludeWeekends;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelect;
  final DateTime? startDate;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(displayMonth.year, displayMonth.month);
    final daysInMonth = DateUtils.getDaysInMonth(
      displayMonth.year,
      displayMonth.month,
    );
    final leadingBlanks = firstDay.weekday % 7;
    final rowCount = ((leadingBlanks + daysInMonth) / 7).ceil();
    final layoutRows = rowCount < 5 ? 5 : rowCount;
    const gridHeight = 214.0;
    const rowGap = 4.0;
    final rowHeight = (gridHeight - (rowGap * (layoutRows - 1))) / layoutRows;

    return SizedBox(
      height: gridHeight,
      child: Column(
        children: [
          for (var row = 0; row < layoutRows; row++) ...[
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _DayCell(
                      date: _dateForCell(
                        firstDay,
                        row * 7 + column - leadingBlanks + 1,
                        daysInMonth,
                      ),
                      endDate: endDate,
                      excludeWeekends: excludeWeekends,
                      firstDate: firstDate,
                      height: rowHeight,
                      lastDate: lastDate,
                      onSelect: onSelect,
                      startDate: startDate,
                    ),
                  ),
              ],
            ),
            if (row != layoutRows - 1) const SizedBox(height: rowGap),
          ],
        ],
      ),
    );
  }

  DateTime? _dateForCell(DateTime firstDay, int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return null;
    return DateTime(firstDay.year, firstDay.month, day);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.endDate,
    required this.excludeWeekends,
    required this.firstDate,
    required this.height,
    required this.lastDate,
    required this.onSelect,
    required this.startDate,
  });

  final DateTime? date;
  final DateTime? endDate;
  final bool excludeWeekends;
  final DateTime firstDate;
  final double height;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelect;
  final DateTime? startDate;

  @override
  Widget build(BuildContext context) {
    final date = this.date;
    if (date == null) {
      return SizedBox(height: height);
    }

    final weekendExcluded = excludeWeekends && isParkingWeekend(date);
    final disabled =
        weekendExcluded ||
        date.isBefore(parkingDateOnly(firstDate)) ||
        date.isAfter(parkingDateOnly(lastDate));
    final selectedStart = _sameDate(date, startDate);
    final selectedEnd = _sameDate(date, endDate);
    final inRange =
        !weekendExcluded &&
        startDate != null &&
        endDate != null &&
        date.isAfter(startDate!) &&
        date.isBefore(endDate!);
    final selected = !weekendExcluded && (selectedStart || selectedEnd);
    final selectedSize = (height - 4).clamp(30.0, 34.0).toDouble();
    final idleSize = (height - 6).clamp(28.0, 32.0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: inRange ? const Color(0xFFEDEEF1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: disabled ? null : () => onSelect(date),
          child: SizedBox(
            height: height,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? selectedSize : idleSize,
                height: selected ? selectedSize : idleSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF0B0B0C)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  date.day.toString(),
                  style: TextStyle(
                    color: disabled
                        ? const Color(0xFFC4C4CA)
                        : selected
                        ? Colors.white
                        : const Color(0xFF0B0B0C),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _previousMonth(DateTime month) =>
    DateTime(month.year, month.month - 1);

DateTime _nextMonth(DateTime month) => DateTime(month.year, month.month + 1);

bool _sameMonth(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month;

bool _sameDate(DateTime left, DateTime? right) =>
    right != null &&
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
