import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LegalConsentText extends StatelessWidget {
  const LegalConsentText({super.key, this.textColor});

  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = textColor ?? const Color(0xFF6B6B6B);
    final linkColor = textColor ?? const Color(0xFF0B0B0C);
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: muted,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      height: 1.5,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'By continuing, you agree to Urban Parking\'s',
          textAlign: TextAlign.center,
          style: mutedStyle,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _InlineLegalLink(
              label: 'Privacy Policy',
              color: linkColor,
              onTap: () => context.push('/privacy'),
            ),
            Text(' and ', textAlign: TextAlign.center, style: mutedStyle),
            _InlineLegalLink(
              label: 'Terms of Use',
              color: linkColor,
              onTap: () => context.push('/terms'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InlineLegalLink extends StatelessWidget {
  const _InlineLegalLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            decoration: TextDecoration.underline,
            decorationColor: color,
            decorationThickness: 1.4,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
