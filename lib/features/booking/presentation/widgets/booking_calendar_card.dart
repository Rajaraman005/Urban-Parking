import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class BookingCalendarCard extends StatelessWidget {
  const BookingCalendarCard({
    required this.availableDays,
    required this.focusedDay,
    required this.onFocusedDayChanged,
    required this.onDaySelected,
    required this.selectedDay,
    super.key,
  });

  final List<DateTime> availableDays;
  final DateTime focusedDay;
  final ValueChanged<DateTime> onFocusedDayChanged;
  final ValueChanged<DateTime> onDaySelected;
  final DateTime selectedDay;

  @override
  Widget build(BuildContext context) {
    final firstDay = availableDays.first;
    final lastDay = availableDays.last;
    final focusedMonth = _monthStart(focusedDay);
    final previousMonthDay = _nearestAvailableMonthDay(
      from: focusedMonth,
      moveForward: false,
    );
    final nextMonthDay = _nearestAvailableMonthDay(
      from: focusedMonth,
      moveForward: true,
    );
    final canChangeMonth = previousMonthDay != null || nextMonthDay != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select date',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 14),
            _CalendarHeader(
              canGoNextMonth: nextMonthDay != null,
              canGoPreviousMonth: previousMonthDay != null,
              focusedMonth: focusedMonth,
              onNextMonth: () {
                if (nextMonthDay != null) {
                  onFocusedDayChanged(nextMonthDay);
                }
              },
              onPreviousMonth: () {
                if (previousMonthDay != null) {
                  onFocusedDayChanged(previousMonthDay);
                }
              },
            ),
            const SizedBox(height: 8),
            TableCalendar<void>(
              key: const ValueKey('booking-calendar'),
              availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              availableGestures: canChangeMonth
                  ? AvailableGestures.horizontalSwipe
                  : AvailableGestures.none,
              calendarFormat: CalendarFormat.month,
              currentDay: DateTime.now(),
              daysOfWeekHeight: 28,
              firstDay: firstDay,
              focusedDay: focusedDay,
              headerVisible: false,
              lastDay: lastDay,
              pageAnimationEnabled: canChangeMonth,
              onDaySelected: (selected, _) =>
                  onDaySelected(_dateOnly(selected)),
              onPageChanged: (day) => onFocusedDayChanged(_dateOnly(day)),
              selectedDayPredicate: (day) => isSameDay(day, selectedDay),
              startingDayOfWeek: StartingDayOfWeek.monday,
              enabledDayPredicate: (day) => _isAvailable(day),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
                defaultTextStyle: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
                disabledTextStyle: const TextStyle(
                  color: Color(0xFFB5BCC7),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
                todayTextStyle: const TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
                todayDecoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                ),
                selectedDecoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
                weekendStyle: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isAvailable(DateTime day) {
    return availableDays.any((entry) => isSameDay(entry, day));
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _monthStart(DateTime value) {
    return DateTime(value.year, value.month);
  }

  DateTime? _nearestAvailableMonthDay({
    required DateTime from,
    required bool moveForward,
  }) {
    final uniqueMonths = <DateTime>{
      for (final day in availableDays) _monthStart(day),
    }.toList()..sort();

    if (moveForward) {
      for (final month in uniqueMonths) {
        if (month.isAfter(from)) {
          return _firstAvailableDayInMonth(month);
        }
      }
      return null;
    }

    for (final month in uniqueMonths.reversed) {
      if (month.isBefore(from)) {
        return _firstAvailableDayInMonth(month);
      }
    }
    return null;
  }

  DateTime? _firstAvailableDayInMonth(DateTime month) {
    for (final day in availableDays) {
      if (day.year == month.year && day.month == month.month) {
        return _dateOnly(day);
      }
    }
    return null;
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.canGoNextMonth,
    required this.canGoPreviousMonth,
    required this.focusedMonth,
    required this.onNextMonth,
    required this.onPreviousMonth,
  });

  final bool canGoNextMonth;
  final bool canGoPreviousMonth;
  final DateTime focusedMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPreviousMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CalendarMonthButton(
          icon: Icons.chevron_left_rounded,
          isEnabled: canGoPreviousMonth,
          onTap: onPreviousMonth,
          semanticLabel: 'Previous month',
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM yyyy').format(focusedMonth),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        _CalendarMonthButton(
          icon: Icons.chevron_right_rounded,
          isEnabled: canGoNextMonth,
          onTap: onNextMonth,
          semanticLabel: 'Next month',
        ),
      ],
    );
  }
}

class _CalendarMonthButton extends StatelessWidget {
  const _CalendarMonthButton({
    required this.icon,
    required this.isEnabled,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final bool isEnabled;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: semanticLabel,
      child: IconButton(
        onPressed: isEnabled ? onTap : null,
        splashRadius: 20,
        icon: Icon(
          icon,
          color: isEnabled ? Colors.black : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }
}
