import 'package:flutter/material.dart';

import '../../../../shared/formatters.dart';
import '../../domain/booking_quote.dart';

class BookingQuoteSummaryCard extends StatelessWidget {
  const BookingQuoteSummaryCard({
    required this.durationLabel,
    required this.subtotalBreakdownLabel,
    required this.windowLabel,
    super.key,
    this.errorText,
    this.isLoading = false,
    this.quote,
  });

  final String durationLabel;
  final String? errorText;
  final bool isLoading;
  final BookingQuote? quote;
  final String subtotalBreakdownLabel;
  final String windowLabel;

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Booking summary',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              windowLabel,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.3,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              durationLabel,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 18),
            if (errorText != null)
              _InlineStatusMessage(
                message: errorText!,
                toneColor: const Color(0xFFB42318),
              )
            else if (isLoading || quote == null)
              const _QuoteSkeleton()
            else
              Column(
                children: [
                  _SubtotalQuoteRow(
                    label: 'Subtotal',
                    value: formatMoney(quote!.subtotal, quote!.currency),
                    detail: subtotalBreakdownLabel,
                  ),
                  const SizedBox(height: 14),
                  _QuoteRow(
                    label: 'Platform fee',
                    value: formatMoney(quote!.platformFee, quote!.currency),
                  ),
                  const SizedBox(height: 14),
                  _QuoteRow(
                    label: 'GST',
                    labelSuffix: const _GstInfoBadge(),
                    value: formatMoney(quote!.taxes, quote!.currency),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                      height: 1,
                      color: Colors.black.withValues(alpha: 0.10),
                    ),
                  ),
                  _QuoteRow(
                    label: 'Total',
                    value: formatMoney(quote!.total, quote!.currency),
                    emphasize: true,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SubtotalQuoteRow extends StatelessWidget {
  const _SubtotalQuoteRow({
    required this.detail,
    required this.label,
    required this.value,
  });

  final String detail;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    const detailStyle = TextStyle(
      color: Color(0xFF6B7280),
      fontSize: 11,
      fontWeight: FontWeight.w700,
      height: 1,
      letterSpacing: 0,
    );
    const valueStyle = TextStyle(
      color: Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w800,
      height: 1,
      letterSpacing: 0,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: detailStyle,
                ),
              ),
              const SizedBox(width: 0),
              SizedBox(
                width: 50,
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.labelSuffix,
  });

  final bool emphasize;
  final String label;
  final Widget? labelSuffix;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.black,
      fontSize: emphasize ? 16 : 14,
      fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
      height: 1,
      letterSpacing: 0,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, style: style)),
              if (labelSuffix != null) ...[
                const SizedBox(width: 6),
                labelSuffix!,
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: emphasize ? 58 : 50,
          child: Text(value, textAlign: TextAlign.right, style: style),
        ),
      ],
    );
  }
}

class _GstInfoBadge extends StatelessWidget {
  const _GstInfoBadge();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'GST is calculated on\nthe platform fee only.',
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 3),
      preferBelow: false,
      child: const SizedBox(
        key: ValueKey('gst-info-badge'),
        width: 18,
        height: 18,
        child: Icon(Icons.error_outline_rounded, color: Colors.black, size: 18),
      ),
    );
  }
}

class _QuoteSkeleton extends StatelessWidget {
  const _QuoteSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _SkeletonLine(widthFactor: 0.82),
        SizedBox(height: 12),
        _SkeletonLine(widthFactor: 0.74),
        SizedBox(height: 12),
        _SkeletonLine(widthFactor: 0.68),
        SizedBox(height: 14),
        _SkeletonLine(widthFactor: 0.90, height: 1),
        SizedBox(height: 14),
        _SkeletonLine(widthFactor: 0.78),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor, this.height = 14});

  final double height;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: SizedBox(height: height),
        ),
      ),
    );
  }
}

class _InlineStatusMessage extends StatelessWidget {
  const _InlineStatusMessage({required this.message, required this.toneColor});

  final String message;
  final Color toneColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: toneColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: toneColor.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          message,
          style: TextStyle(
            color: toneColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            height: 1.35,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
