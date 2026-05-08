import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/formatters.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/state_view.dart';
import '../domain/booking.dart';
import '../domain/booking_quote.dart';
import '../../parking/domain/parking_spot.dart';
import 'booking_controller.dart';
import 'widgets/booking_calendar_card.dart';
import 'widgets/booking_quote_summary_card.dart';
import 'widgets/booking_selector_field.dart';
import 'widgets/booking_time_range_sheet.dart';
import 'widgets/booking_vehicle_toggle.dart';

class BookingScheduleScreen extends ConsumerStatefulWidget {
  const BookingScheduleScreen({required this.spotId, super.key});

  final String spotId;

  @override
  ConsumerState<BookingScheduleScreen> createState() =>
      _BookingScheduleScreenState();
}

class _BookingScheduleScreenState extends ConsumerState<BookingScheduleScreen> {
  static const _uuid = Uuid();
  static const _darkOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.black,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  );

  BookingTimeSelection? _selection;
  BookingVehicleKind _selectedVehicleKind = BookingVehicleKind.car;
  DateTime? _focusedDay;
  bool _hasConfirmedEndTime = false;
  bool _hasConfirmedStartTime = false;
  String? _reserveAttemptIdempotencyKey;
  DateTime? _selectedDay;
  String? _seededSpotId;

  @override
  Widget build(BuildContext context) {
    final spotAsync = ref.watch(bookingSpotProvider(widget.spotId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _darkOverlayStyle,
      child: spotAsync.when(
        loading: () => _BookingScheduleShell(
          title: 'Schedule Booking',
          onBack: _handleBack,
          child: const Center(
            child: StateView(
              title: 'Loading booking',
              body: 'Preparing available dates and pricing.',
              isLoading: true,
            ),
          ),
        ),
        error: (error, _) => _BookingScheduleShell(
          title: 'Schedule Booking',
          onBack: _handleBack,
          child: Center(
            child: StateView(
              title: 'Could not load booking',
              body: error.toString(),
              actionLabel: 'Back',
              onAction: _handleBack,
            ),
          ),
        ),
        data: (spot) {
          _seedSelection(spot);
          final selection = _selection;
          if (selection == null ||
              _selectedDay == null ||
              _focusedDay == null) {
            return _BookingScheduleShell(
              title: 'Schedule Booking',
              onBack: _handleBack,
              child: Center(
                child: StateView(
                  title: 'No booking window',
                  body:
                      'This space does not have an available booking slot right now.',
                  actionLabel: 'Back to details',
                  onAction: _handleBack,
                ),
              ),
            );
          }

          final availableDays = BookingTimeSelection.availableDatesFor(spot);
          final quoteAsync = ref.watch(
            bookingQuoteProvider(
              BookingQuoteRequest(
                spotId: spot.id,
                startAt: selection.startAt,
                endAt: selection.endAt,
              ),
            ),
          );
          final displayQuote = quoteAsync.asData?.value == null
              ? null
              : _displayQuoteForVehicle(
                  baseQuote: quoteAsync.asData!.value,
                  vehicleKind: _selectedVehicleKind,
                );
          final hasCompletedTimeDetails =
              _hasConfirmedStartTime && _hasConfirmedEndTime;
          final submitState = ref.watch(bookingSubmitControllerProvider);
          final isSubmitting = submitState.isLoading;
          final canReserve =
              hasCompletedTimeDetails &&
              quoteAsync.hasValue &&
              !quoteAsync.isLoading &&
              !quoteAsync.hasError &&
              !isSubmitting;
          final totalText = hasCompletedTimeDetails
              ? quoteAsync.maybeWhen(
                  data: (_) => displayQuote == null
                      ? 'Updating...'
                      : formatMoney(displayQuote.total, displayQuote.currency),
                  orElse: () => 'Updating...',
                )
              : 'Select time';

          return _BookingScheduleShell(
            title: 'Schedule Booking',
            onBack: _handleBack,
            bottomBar: _BookingBottomBar(
              buttonLabel: isSubmitting ? 'Reserving...' : 'Reserve Slot',
              compactTotalText: !canReserve,
              totalText: totalText,
              onTap: canReserve
                  ? () => unawaited(_reserveSlot(spot, selection))
                  : null,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              children: [
                _BookingSpotSummaryCard(spot: spot),
                const SizedBox(height: 18),
                BookingCalendarCard(
                  availableDays: availableDays,
                  focusedDay: _focusedDay!,
                  onFocusedDayChanged: _handleFocusedDayChanged,
                  onDaySelected: (day) => _handleDaySelected(spot, day),
                  selectedDay: _selectedDay!,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Choose time',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    const maxFieldWidth = 142.0;
                    final availableFieldWidth =
                        (constraints.maxWidth - spacing) / 2;
                    final fieldWidth = availableFieldWidth > maxFieldWidth
                        ? maxFieldWidth
                        : availableFieldWidth;

                    return Wrap(
                      alignment: WrapAlignment.center,
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: BookingSelectorField(
                            icon: Icons.access_time_rounded,
                            label: 'From',
                            onTap: () => _showTimeRangePicker(spot),
                            value: _timeLabel(selection.startAt),
                            helper: _shortDateLabel(selection.startAt),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: BookingSelectorField(
                            icon: Icons.access_time_rounded,
                            label: 'To',
                            onTap: () => _showTimeRangePicker(spot),
                            value: _timeLabel(selection.endAt),
                            helper: _shortDateLabel(selection.endAt),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Vehicle type',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                BookingVehicleToggle(
                  selectedKind: _selectedVehicleKind,
                  onChanged: (kind) {
                    if (_selectedVehicleKind == kind) return;
                    setState(() {
                      _reserveAttemptIdempotencyKey = null;
                      _selectedVehicleKind = kind;
                    });
                  },
                ),
                const SizedBox(height: 18),
                BookingQuoteSummaryCard(
                  durationLabel: _durationLabel(
                    selection.startAt,
                    selection.endAt,
                  ),
                  errorText: quoteAsync.hasError
                      ? 'Could not refresh the booking total right now.'
                      : null,
                  isLoading: quoteAsync.isLoading,
                  quote: displayQuote,
                  subtotalBreakdownLabel: _subtotalBreakdownLabel(
                    spot: spot,
                    startAt: selection.startAt,
                    endAt: selection.endAt,
                  ),
                  windowLabel: _windowLabel(selection.startAt, selection.endAt),
                ),
                const SizedBox(height: 10),
                const _LateArrivalPolicyNotice(),
              ],
            ),
          );
        },
      ),
    );
  }

  void _seedSelection(ParkingSpot spot) {
    if (_seededSpotId == spot.id &&
        _selection != null &&
        _selectedDay != null) {
      return;
    }

    final initial = BookingTimeSelection.initialFor(spot);
    _seededSpotId = spot.id;
    _selection = initial;
    _hasConfirmedEndTime = false;
    _hasConfirmedStartTime = false;
    _reserveAttemptIdempotencyKey = null;
    _selectedVehicleKind = _defaultVehicleKindFor(spot);
    _selectedDay = initial == null ? null : _dateOnly(initial.startAt);
    _focusedDay = initial == null ? null : _dateOnly(initial.startAt);
  }

  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go('/booking/${widget.spotId}');
  }

  void _handleDaySelected(ParkingSpot spot, DateTime day) {
    final startOptions = BookingTimeSelection.startOptionsFor(spot, day);
    if (startOptions.isEmpty) return;
    final startAt = startOptions.first;
    final endOptions = BookingTimeSelection.endOptionsFor(spot, startAt);
    if (endOptions.isEmpty) return;

    setState(() {
      _hasConfirmedEndTime = false;
      _hasConfirmedStartTime = false;
      _reserveAttemptIdempotencyKey = null;
      _selectedDay = _dateOnly(day);
      _focusedDay = _dateOnly(day);
      _selection = BookingTimeSelection(
        startAt: startAt,
        endAt: endOptions.first,
      );
    });
  }

  void _handleFocusedDayChanged(DateTime day) {
    setState(() {
      _focusedDay = _dateOnly(day);
    });
  }

  // ignore: unused_element
  Future<void> _showStartTimePicker(ParkingSpot spot) {
    return _showTimeRangePicker(spot);
  }

  // ignore: unused_element
  Future<void> _showEndTimePicker(ParkingSpot spot) {
    return _showTimeRangePicker(spot);
  }

  Future<void> _showTimeRangePicker(ParkingSpot spot) async {
    if (_selectedDay == null || _selection == null) return;

    final startOptions = BookingTimeSelection.startOptionsFor(
      spot,
      _selectedDay!,
    );
    if (startOptions.isEmpty) return;

    final selectedStart = startOptions.contains(_selection!.startAt)
        ? _selection!.startAt
        : startOptions.first;
    final endOptions = BookingTimeSelection.endOptionsFor(spot, selectedStart);
    if (endOptions.isEmpty) return;

    final selectedEnd = endOptions.contains(_selection!.endAt)
        ? _selection!.endAt
        : endOptions.first;

    final picked = await showBookingTimeRangeSheet(
      context: context,
      selectedDate: _selectedDay!,
      initialSelection: BookingTimeSelection(
        startAt: selectedStart,
        endAt: selectedEnd,
      ),
      startOptions: startOptions,
      endOptionsFor: (startAt) =>
          BookingTimeSelection.endOptionsFor(spot, startAt),
    );
    if (!mounted || picked == null) return;

    setState(() {
      _hasConfirmedEndTime = true;
      _hasConfirmedStartTime = true;
      _reserveAttemptIdempotencyKey = null;
      _selection = picked;
      _selectedDay = _dateOnly(picked.startAt);
      _focusedDay = _dateOnly(picked.startAt);
    });
  }

  Future<void> _reserveSlot(
    ParkingSpot spot,
    BookingTimeSelection selection,
  ) async {
    final idempotencyKey = _reserveAttemptIdempotencyKey ?? _uuid.v4();
    _reserveAttemptIdempotencyKey = idempotencyKey;

    try {
      final booking = await ref
          .read(bookingSubmitControllerProvider.notifier)
          .createBooking(
            CreateBookingRequest(
              endAt: selection.endAt,
              idempotencyKey: idempotencyKey,
              spotId: spot.id,
              startAt: selection.startAt,
              vehicleKind: _selectedVehicleKind.name,
            ),
          );
      _reserveAttemptIdempotencyKey = null;
      if (!mounted) return;
      AppToast.success(
        context,
        booking.status == BookingStatus.pending
            ? 'Request sent'
            : 'Booking confirmed',
      );
      await _showBookingResult(booking);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, _bookingErrorMessage(error));
    }
  }

  Future<void> _showBookingResult(ParkingBooking booking) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _BookingResultSheet(booking: booking),
    );
  }

  String _bookingErrorMessage(Object error) {
    if (error is AppFailure) return error.message;
    return 'Could not reserve this slot. Please try again.';
  }

  String _timeLabel(DateTime value) {
    return DateFormat('h:mm a').format(value);
  }

  // ignore: unused_element
  String _sheetTimeLabel(DateTime value) {
    return '${DateFormat('EEE, d MMM').format(value)}  |  ${_timeLabel(value)}';
  }

  String _shortDateLabel(DateTime value) {
    return DateFormat('EEE, d MMM').format(value);
  }

  String _longDateTimeLabel(DateTime value) {
    return DateFormat('EEE, d MMM h:mm a').format(value);
  }

  String _windowLabel(DateTime startAt, DateTime endAt) {
    if (_isSameCalendarDay(startAt, endAt)) {
      return '${_longDateTimeLabel(startAt)} to ${_timeLabel(endAt)}';
    }
    return '${_longDateTimeLabel(startAt)} to ${_longDateTimeLabel(endAt)}';
  }

  String _durationLabel(DateTime startAt, DateTime endAt) {
    final totalMinutes = endAt.difference(startAt).inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    return '$hours h $minutes min';
  }

  String _subtotalBreakdownLabel({
    required ParkingSpot spot,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final totalMinutes = endAt.difference(startAt).inMinutes;

    switch (spot.cadence) {
      case BookingCadence.hourly:
        final hours = (totalMinutes / 60).ceil().clamp(1, 24);
        return '$hours x ${formatMoney(spot.price, spot.currency)}/hr';
      case BookingCadence.daily:
        final days = (totalMinutes / Duration.minutesPerDay).ceil().clamp(
          1,
          365,
        );
        return '$days x ${formatMoney(spot.price, spot.currency)}/day';
      case BookingCadence.monthly:
        final months = (totalMinutes / (Duration.minutesPerDay * 30))
            .ceil()
            .clamp(1, 12);
        return '$months x ${formatMoney(spot.price, spot.currency)}/mo';
    }
  }

  BookingQuote _displayQuoteForVehicle({
    required BookingQuote baseQuote,
    required BookingVehicleKind vehicleKind,
  }) {
    final platformFee = (baseQuote.subtotal * _platformFeeRate(vehicleKind))
        .round();
    final taxes = (platformFee * 0.18).round();
    return baseQuote.copyWith(
      platformFee: platformFee,
      taxes: taxes,
      total: baseQuote.subtotal + platformFee + taxes,
    );
  }

  double _platformFeeRate(BookingVehicleKind vehicleKind) {
    switch (vehicleKind) {
      case BookingVehicleKind.bike:
        return 0.10;
      case BookingVehicleKind.car:
        return 0.15;
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameCalendarDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  BookingVehicleKind _defaultVehicleKindFor(ParkingSpot spot) {
    final title = spot.title.toLowerCase();
    if (title.contains('car')) {
      return BookingVehicleKind.car;
    }
    if (title.contains('bike') ||
        title.contains('two wheeler') ||
        title.contains('two-wheeler') ||
        spot.amenities.contains(ParkingAmenity.twoWheeler)) {
      return BookingVehicleKind.bike;
    }
    return BookingVehicleKind.car;
  }
}

class _LateArrivalPolicyNotice extends StatelessWidget {
  const _LateArrivalPolicyNotice();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        'Late arrivals may incur additional charges under the host policy.',
        key: ValueKey('late-arrival-policy-notice'),
        style: TextStyle(
          color: Color(0xFFB42318),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.25,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _BookingResultSheet extends StatelessWidget {
  const _BookingResultSheet({required this.booking});

  final ParkingBooking booking;

  @override
  Widget build(BuildContext context) {
    final isPending = booking.status == BookingStatus.pending;
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: isPending
                    ? colors.tertiaryContainer
                    : colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  isPending
                      ? Icons.pending_actions_outlined
                      : Icons.check_circle_outline_rounded,
                  color: isPending
                      ? colors.onTertiaryContainer
                      : colors.onPrimaryContainer,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isPending ? 'Request sent' : 'Booking confirmed',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isPending
                  ? 'The host has 24 hours to approve or reject this booking.'
                  : 'Your parking slot is approved for this time window.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 18),
            _ResultFact(
              icon: Icons.schedule_rounded,
              label: _resultWindowLabel(booking.startAt, booking.endAt),
            ),
            const SizedBox(height: 10),
            _ResultFact(
              icon: Icons.payments_outlined,
              label: formatMoney(booking.total, booking.currency),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  String _resultWindowLabel(DateTime startAt, DateTime endAt) {
    final sameDay =
        startAt.year == endAt.year &&
        startAt.month == endAt.month &&
        startAt.day == endAt.day;
    final start = DateFormat('EEE, d MMM h:mm a').format(startAt);
    final end = sameDay
        ? DateFormat('h:mm a').format(endAt)
        : DateFormat('EEE, d MMM h:mm a').format(endAt);
    return '$start to $end';
  }
}

class _ResultFact extends StatelessWidget {
  const _ResultFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colors.onSurfaceVariant, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingScheduleShell extends StatelessWidget {
  const _BookingScheduleShell({
    required this.child,
    required this.onBack,
    required this.title,
    this.bottomBar,
  });

  final Widget child;
  final Widget? bottomBar;
  final VoidCallback onBack;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      bottomNavigationBar: bottomBar,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: _BookingTopBar(onBack: onBack, title: title),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(top: false, child: child),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingTopBar extends StatelessWidget {
  const _BookingTopBar({required this.onBack, required this.title});

  final VoidCallback onBack;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _TopActionButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
              tooltip: 'Back',
            ),
          ),
          Center(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _BookingSpotSummaryCard extends StatelessWidget {
  const _BookingSpotSummaryCard({required this.spot});

  final ParkingSpot spot;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking for',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    spot.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    spot.address.isEmpty ? spot.locality : spot.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  '${formatMoney(spot.price, spot.currency)}/${_cadenceSuffix(spot.cadence)}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cadenceSuffix(BookingCadence cadence) {
    switch (cadence) {
      case BookingCadence.hourly:
        return 'hr';
      case BookingCadence.daily:
        return 'day';
      case BookingCadence.monthly:
        return 'mo';
    }
  }
}

class _BookingBottomBar extends StatelessWidget {
  const _BookingBottomBar({
    required this.buttonLabel,
    required this.compactTotalText,
    required this.totalText,
    this.onTap,
  });

  final String buttonLabel;
  final bool compactTotalText;
  final VoidCallback? onTap;
  final String totalText;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Estimated total',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 24,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                totalText,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: compactTotalText ? 16 : 20,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: Ink(
                        decoration: BoxDecoration(
                          color: onTap == null
                              ? Colors.black.withValues(alpha: 0.42)
                              : Colors.black,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: InkWell(
                          key: const ValueKey('reserve-slot-cta'),
                          onTap: onTap,
                          child: SizedBox(
                            height: 56,
                            child: Center(
                              child: Text(
                                buttonLabel,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
