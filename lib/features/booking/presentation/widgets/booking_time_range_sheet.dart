import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../booking_controller.dart';

typedef BookingEndOptionsResolver = List<DateTime> Function(DateTime startAt);

Future<BookingTimeSelection?> showBookingTimeRangeSheet({
  required BuildContext context,
  required DateTime selectedDate,
  required BookingTimeSelection initialSelection,
  required List<DateTime> startOptions,
  required BookingEndOptionsResolver endOptionsFor,
}) {
  return showModalBottomSheet<BookingTimeSelection>(
    context: context,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    isDismissible: true,
    isScrollControlled: true,
    builder: (context) {
      return _BookingTimeRangeSheet(
        endOptionsFor: endOptionsFor,
        initialSelection: initialSelection,
        selectedDate: selectedDate,
        startOptions: startOptions,
      );
    },
  );
}

class _BookingTimeRangeSheet extends StatefulWidget {
  const _BookingTimeRangeSheet({
    required this.endOptionsFor,
    required this.initialSelection,
    required this.selectedDate,
    required this.startOptions,
  });

  final BookingEndOptionsResolver endOptionsFor;
  final BookingTimeSelection initialSelection;
  final DateTime selectedDate;
  final List<DateTime> startOptions;

  @override
  State<_BookingTimeRangeSheet> createState() => _BookingTimeRangeSheetState();
}

class _BookingTimeRangeSheetState extends State<_BookingTimeRangeSheet> {
  late final FixedExtentScrollController _startController;
  late FixedExtentScrollController _endController;
  late DateTime _selectedStart;
  late DateTime _selectedEnd;
  late List<DateTime> _endOptions;

  @override
  void initState() {
    super.initState();
    _selectedStart = _matchingOrFallbackStart();
    _endOptions = widget.endOptionsFor(_selectedStart);
    _selectedEnd = _matchingOrFallbackEnd();
    _startController = FixedExtentScrollController(
      initialItem: widget.startOptions.indexOf(_selectedStart),
    );
    _endController = FixedExtentScrollController(
      initialItem: _endOptions.indexOf(_selectedEnd),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final wheelHeight = screenHeight < 720 ? 112.0 : 128.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 4),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.80),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Choose time',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat(
                                    'EEE, d MMMM',
                                  ).format(widget.selectedDate),
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Material(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              key: const ValueKey('time-range-close'),
                              onTap: () => Navigator.of(context).pop(),
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.black,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeWheelCard(
                              controller: _startController,
                              onSelectedItemChanged: _handleStartChanged,
                              options: widget.startOptions,
                              wheelHeight: wheelHeight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TimeWheelCard(
                              controller: _endController,
                              onSelectedItemChanged: _handleEndChanged,
                              options: _endOptions,
                              wheelHeight: wheelHeight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: Ink(
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: InkWell(
                              key: const ValueKey('time-range-apply'),
                              onTap: _applySelection,
                              child: const SizedBox(
                                height: 52,
                                child: Center(
                                  child: Text(
                                    'Apply time',
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
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _applySelection() {
    Navigator.of(
      context,
    ).pop(BookingTimeSelection(startAt: _selectedStart, endAt: _selectedEnd));
  }

  void _handleEndChanged(int index) {
    if (index < 0 || index >= _endOptions.length) return;
    setState(() {
      _selectedEnd = _endOptions[index];
    });
  }

  void _handleStartChanged(int index) {
    if (index < 0 || index >= widget.startOptions.length) return;

    final nextStart = widget.startOptions[index];
    final nextEndOptions = widget.endOptionsFor(nextStart);
    final nextEnd = nextEndOptions.contains(_selectedEnd)
        ? _selectedEnd
        : nextEndOptions.first;
    final nextEndIndex = nextEndOptions.indexOf(nextEnd);
    final previousEndController = _endController;
    final replacementEndController = FixedExtentScrollController(
      initialItem: nextEndIndex,
    );

    setState(() {
      _selectedStart = nextStart;
      _selectedEnd = nextEnd;
      _endOptions = nextEndOptions;
      _endController = replacementEndController;
    });

    previousEndController.dispose();
  }

  DateTime _matchingOrFallbackEnd() {
    if (_endOptions.contains(widget.initialSelection.endAt)) {
      return widget.initialSelection.endAt;
    }
    return _endOptions.first;
  }

  DateTime _matchingOrFallbackStart() {
    if (widget.startOptions.contains(widget.initialSelection.startAt)) {
      return widget.initialSelection.startAt;
    }
    return widget.startOptions.first;
  }
}

class _TimeWheelCard extends StatelessWidget {
  const _TimeWheelCard({
    required this.controller,
    required this.onSelectedItemChanged,
    required this.options,
    required this.wheelHeight,
  });

  final FixedExtentScrollController controller;
  final ValueChanged<int> onSelectedItemChanged;
  final List<DateTime> options;
  final double wheelHeight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: wheelHeight,
              child: CupertinoPicker(
                backgroundColor: Colors.transparent,
                diameterRatio: 1.2,
                itemExtent: 42,
                magnification: 1.1,
                scrollController: controller,
                selectionOverlay: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                squeeze: 1.05,
                useMagnifier: true,
                onSelectedItemChanged: onSelectedItemChanged,
                children: options
                    .map(
                      (option) => Center(
                        child: Text(
                          DateFormat('h:mm a').format(option),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
