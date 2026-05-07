import 'package:flutter/material.dart';

import '../../domain/parking_availability.dart';
import 'availability_field_label.dart';

class AvailabilityTimeField extends StatelessWidget {
  const AvailabilityTimeField({
    required this.label,
    required this.onTap,
    required this.value,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE4E4E7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AvailabilityFieldLabel(label),
                    const SizedBox(height: 8),
                    Text(
                      parkingMinuteLabel(value),
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
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF71717A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<int?> showAvailabilityMinutePicker({
  required BuildContext context,
  required int currentValue,
  required String label,
  required int maxMinute,
  required int minMinute,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) => _MinutePickerSheet(
      currentValue: currentValue,
      label: label,
      maxMinute: maxMinute,
      minMinute: minMinute,
    ),
  );
}

class _MinutePickerSheet extends StatefulWidget {
  const _MinutePickerSheet({
    required this.currentValue,
    required this.label,
    required this.maxMinute,
    required this.minMinute,
  });

  final int currentValue;
  final String label;
  final int maxMinute;
  final int minMinute;

  @override
  State<_MinutePickerSheet> createState() => _MinutePickerSheetState();
}

class _MinutePickerSheetState extends State<_MinutePickerSheet> {
  static const _optionHeight = 46.0;
  static const _optionGap = 6.0;
  static const _optionExtent = _optionHeight + _optionGap;
  static const _listHorizontalPadding = 14.0;

  late final List<int> _options;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _options = [
      for (
        var minute = widget.minMinute;
        minute <= widget.maxMinute;
        minute += 30
      )
        minute,
    ];
    final selectedIndex = _options.indexOf(widget.currentValue);
    _scrollController = ScrollController(
      initialScrollOffset: selectedIndex <= 0
          ? 0
          : selectedIndex * _optionExtent,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.60,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E4E7),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
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
              ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const _MinutePickerScrollBehavior(),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      _listHorizontalPadding,
                      0,
                      _listHorizontalPadding,
                      14 + bottomInset,
                    ),
                    cacheExtent: _optionExtent * 10,
                    itemExtent: _optionExtent,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _options.length,
                    itemBuilder: (context, index) {
                      final value = _options[index];
                      return _MinuteOptionTile(
                        key: ValueKey(value),
                        height: _optionHeight,
                        label: parkingMinuteLabel(value),
                        selected: value == widget.currentValue,
                        onTap: () => Navigator.of(context).pop(value),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinuteOptionTile extends StatelessWidget {
  const _MinuteOptionTile({
    required this.height,
    required this.label,
    required this.onTap,
    required this.selected,
    super.key,
  });

  final double height;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: _MinutePickerSheetState._optionGap,
        ),
        child: Material(
          color: selected ? const Color(0xFF0B0B0C) : const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF0B0B0C),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinutePickerScrollBehavior extends ScrollBehavior {
  const _MinutePickerScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
